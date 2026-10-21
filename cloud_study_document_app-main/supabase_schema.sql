-- ============================================================================
-- HỆ THỐNG CƠ SỞ DỮ LIỆU SUPABASE & CHÍNH SÁCH BẢO MẬT ROW LEVEL SECURITY (RLS)
-- Dự án: Cloud Study Document App
-- Mô hình kết hợp: Firebase Storage (Lưu tệp) + Supabase PostgreSQL (Metadata & Phân quyền)
-- ============================================================================

-- Bật extension hỗ trợ UUID nếu chưa có
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. BẢNG NGƯỜI DÙNG (users / profiles)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.users (
    id VARCHAR(128) PRIMARY KEY, -- Khớp với Firebase UID hoặc Supabase auth.users ID
    email VARCHAR(255) NOT NULL UNIQUE,
    display_name VARCHAR(255),
    avatar_url TEXT,
    role VARCHAR(50) DEFAULT 'student',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Index tăng tốc tìm kiếm người dùng theo email khi chia sẻ tài liệu
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

-- ============================================================================
-- 2. BẢNG TÀI LIỆU HỌC TẬP (documents)
-- Lưu metadata và đường dẫn tham chiếu đến Firebase Cloud Storage
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.documents (
    id VARCHAR(128) PRIMARY KEY,
    owner_id VARCHAR(128) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    course_id VARCHAR(64) DEFAULT '',
    title VARCHAR(255) NOT NULL,
    description TEXT DEFAULT '',
    document_type VARCHAR(50) NOT NULL DEFAULT 'lecture', -- lecture, exercise, reference
    status VARCHAR(50) NOT NULL DEFAULT 'todo',           -- todo, inProgress, completed
    
    -- Liên kết Firebase Storage:
    file_url TEXT DEFAULT '',                             -- Download URL (có token hoặc public link)
    file_path TEXT DEFAULT '',                            -- Cấu trúc: study_documents/{userId}/{docId}/{fileName}
    file_name VARCHAR(255) DEFAULT '',                    -- Tên tệp gốc đính kèm
    file_size BIGINT DEFAULT 0,                           -- Kích thước tệp (bytes)
    file_type VARCHAR(100) DEFAULT '',                    -- MIME type (application/pdf, docx, etc.)
    
    tags TEXT[] DEFAULT '{}',
    deadline TIMESTAMPTZ,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_public BOOLEAN DEFAULT FALSE,                      -- Cho phép xem công khai nếu bật
    
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Indexes tối ưu hóa tìm kiếm tài liệu
CREATE INDEX IF NOT EXISTS idx_documents_owner_id ON public.documents(owner_id);
CREATE INDEX IF NOT EXISTS idx_documents_course_id ON public.documents(course_id);
CREATE INDEX IF NOT EXISTS idx_documents_type ON public.documents(document_type);
CREATE INDEX IF NOT EXISTS idx_documents_status ON public.documents(status);
CREATE INDEX IF NOT EXISTS idx_documents_tags ON public.documents USING GIN(tags);

-- Full-Text Search Index (tìm kiếm nhanh theo tiêu đề và mô tả)
CREATE INDEX IF NOT EXISTS idx_documents_fts ON public.documents 
USING GIN (to_tsvector('english', title || ' ' || COALESCE(description, '')));

-- ============================================================================
-- 3. BẢNG QUYỀN CHIA SẺ (document_permissions)
-- Quản lý quyền truy cập chi tiết: viewer (chỉ đọc), editor (chỉnh sửa), admin (quản lý)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.document_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id VARCHAR(128) NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user_email VARCHAR(255) NOT NULL,
    permission_role VARCHAR(50) NOT NULL DEFAULT 'viewer', -- 'viewer', 'editor', 'admin'
    shared_by VARCHAR(128) REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    
    CONSTRAINT uq_document_user_permission UNIQUE (document_id, user_id),
    CONSTRAINT chk_permission_role CHECK (permission_role IN ('viewer', 'editor', 'admin'))
);

CREATE INDEX IF NOT EXISTS idx_doc_perm_doc_id ON public.document_permissions(document_id);
CREATE INDEX IF NOT EXISTS idx_doc_perm_user_id ON public.document_permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_doc_perm_email ON public.document_permissions(user_email);

-- ============================================================================
-- 4. TRIGGER TỰ ĐỘNG CẬP NHẬT updated_at
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc'::text, NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_timestamp_users ON public.users;
CREATE TRIGGER set_timestamp_users
BEFORE UPDATE ON public.users
FOR EACH ROW EXECUTE PROCEDURE trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp_documents ON public.documents;
CREATE TRIGGER set_timestamp_documents
BEFORE UPDATE ON public.documents
FOR EACH ROW EXECUTE PROCEDURE trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp_permissions ON public.document_permissions;
CREATE TRIGGER set_timestamp_permissions
BEFORE UPDATE ON public.document_permissions
FOR EACH ROW EXECUTE PROCEDURE trigger_set_timestamp();

-- ============================================================================
-- 5. THIẾT LẬP ROW LEVEL SECURITY (RLS) - BẢO MẬT & PHÂN QUYỀN DỮ LIỆU
-- ============================================================================

-- Bật tính năng RLS trên tất cả các bảng
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_permissions ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 5.1 Policies cho bảng `users`
-- ----------------------------------------------------------------------------
-- Người dùng đã đăng nhập có thể xem thông tin hồ sơ của mọi người (để tìm kiếm bạn bè chia sẻ)
DROP POLICY IF EXISTS "Authenticated users can view users" ON public.users;
CREATE POLICY "Authenticated users can view users"
ON public.users FOR SELECT
TO authenticated
USING (true);

-- Người dùng chỉ được sửa thông tin của chính mình
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE
TO authenticated
USING (id = auth.uid()::text)
WITH CHECK (id = auth.uid()::text);

-- Cho phép chèn bản ghi người dùng khi đăng ký / đồng bộ
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile"
ON public.users FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid()::text);

-- ----------------------------------------------------------------------------
-- 5.2 Policies cho bảng `documents`
-- ----------------------------------------------------------------------------
-- (A) SELECT (Đọc tài liệu):
-- Người dùng được đọc tài liệu nếu:
-- 1. Là chủ sở hữu (owner_id)
-- 2. HOẶC tài liệu được bật cờ is_public = true
-- 3. HOẶC được cấp quyền (viewer/editor/admin) trong bảng document_permissions
DROP POLICY IF EXISTS "Read permitted documents" ON public.documents;
CREATE POLICY "Read permitted documents"
ON public.documents FOR SELECT
TO authenticated
USING (
    owner_id = auth.uid()::text
    OR is_public = TRUE
    OR EXISTS (
        SELECT 1 FROM public.document_permissions dp
        WHERE dp.document_id = documents.id
          AND dp.user_id = auth.uid()::text
    )
);

-- (B) INSERT (Tạo tài liệu mới):
-- Người dùng chỉ được tạo tài liệu do chính mình sở hữu
DROP POLICY IF EXISTS "Insert own documents" ON public.documents;
CREATE POLICY "Insert own documents"
ON public.documents FOR INSERT
TO authenticated
WITH CHECK (
    owner_id = auth.uid()::text
);

-- (C) UPDATE (Cập nhật thông tin tài liệu):
-- Chỉ chủ sở hữu (owner) HOẶC thành viên có quyền 'editor'/'admin' mới được sửa
DROP POLICY IF EXISTS "Update owned or editor documents" ON public.documents;
CREATE POLICY "Update owned or editor documents"
ON public.documents FOR UPDATE
TO authenticated
USING (
    owner_id = auth.uid()::text
    OR EXISTS (
        SELECT 1 FROM public.document_permissions dp
        WHERE dp.document_id = documents.id
          AND dp.user_id = auth.uid()::text
          AND dp.permission_role IN ('editor', 'admin')
    )
)
WITH CHECK (
    owner_id = auth.uid()::text
    OR EXISTS (
        SELECT 1 FROM public.document_permissions dp
        WHERE dp.document_id = documents.id
          AND dp.user_id = auth.uid()::text
          AND dp.permission_role IN ('editor', 'admin')
    )
);

-- (D) DELETE (Xóa tài liệu):
-- Chỉ duy nhất chủ sở hữu (owner) mới có quyền xóa tài liệu
DROP POLICY IF EXISTS "Delete only owned documents" ON public.documents;
CREATE POLICY "Delete only owned documents"
ON public.documents FOR DELETE
TO authenticated
USING (
    owner_id = auth.uid()::text
);

-- ----------------------------------------------------------------------------
-- 5.3 Policies cho bảng `document_permissions` (Quyền chia sẻ)
-- ----------------------------------------------------------------------------
-- (A) SELECT (Xem danh sách quyền):
-- Chủ tài liệu hoặc người được chia sẻ có thể xem danh sách quyền
DROP POLICY IF EXISTS "View permissions" ON public.document_permissions;
CREATE POLICY "View permissions"
ON public.document_permissions FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()::text
    OR EXISTS (
        SELECT 1 FROM public.documents d
        WHERE d.id = document_permissions.document_id
          AND d.owner_id = auth.uid()::text
    )
);

-- (B) INSERT (Chia sẻ tài liệu):
-- Chỉ chủ sở hữu tài liệu mới có quyền chia sẻ cho người khác
DROP POLICY IF EXISTS "Owner can grant permissions" ON public.document_permissions;
CREATE POLICY "Owner can grant permissions"
ON public.document_permissions FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.documents d
        WHERE d.id = document_permissions.document_id
          AND d.owner_id = auth.uid()::text
    )
);

-- (C) UPDATE (Chỉnh sửa vai trò quyền):
-- Chỉ chủ sở hữu tài liệu mới được cập nhật vai trò (viewer <-> editor)
DROP POLICY IF EXISTS "Owner can update permissions" ON public.document_permissions;
CREATE POLICY "Owner can update permissions"
ON public.document_permissions FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.documents d
        WHERE d.id = document_permissions.document_id
          AND d.owner_id = auth.uid()::text
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.documents d
        WHERE d.id = document_permissions.document_id
          AND d.owner_id = auth.uid()::text
    )
);

-- (D) DELETE (Thu hồi quyền chia sẻ):
-- Chủ sở hữu có thể thu hồi bất kỳ quyền nào, hoặc chính người được chia sẻ tự gỡ bỏ
DROP POLICY IF EXISTS "Revoke permissions" ON public.document_permissions;
CREATE POLICY "Revoke permissions"
ON public.document_permissions FOR DELETE
TO authenticated
USING (
    user_id = auth.uid()::text
    OR EXISTS (
        SELECT 1 FROM public.documents d
        WHERE d.id = document_permissions.document_id
          AND d.owner_id = auth.uid()::text
    )
);

-- ============================================================================
-- 6. TẠO HÀM TÌM KIẾM TÀI LIỆU TOÀN DIỆN (Full-text Search RPC Function)
-- ============================================================================
CREATE OR REPLACE FUNCTION search_user_documents(
    search_query TEXT,
    filter_course_id TEXT DEFAULT NULL,
    filter_type TEXT DEFAULT NULL,
    filter_status TEXT DEFAULT NULL
)
RETURNS SETOF public.documents
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT d.*
    FROM public.documents d
    WHERE 
        -- RLS Filter Check:
        (
            d.owner_id = auth.uid()::text
            OR d.is_public = TRUE
            OR EXISTS (
                SELECT 1 FROM public.document_permissions dp
                WHERE dp.document_id = d.id AND dp.user_id = auth.uid()::text
            )
        )
        -- Query Match:
        AND (
            search_query IS NULL 
            OR search_query = '' 
            OR d.title ILIKE '%' || search_query || '%'
            OR d.description ILIKE '%' || search_query || '%'
            OR search_query = ANY(d.tags)
        )
        -- Filter Course:
        AND (filter_course_id IS NULL OR filter_course_id = '' OR d.course_id = filter_course_id)
        -- Filter Type:
        AND (filter_type IS NULL OR filter_type = '' OR d.document_type = filter_type)
        -- Filter Status:
        AND (filter_status IS NULL OR filter_status = '' OR d.status = filter_status)
    ORDER BY d.is_pinned DESC, d.created_at DESC;
$$;
