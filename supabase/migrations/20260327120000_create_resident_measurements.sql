-- ============================================
-- Table: resident_measurements
-- ============================================
-- เก็บค่าที่วัดนานๆ ครั้ง เช่น น้ำหนัก ส่วนสูง BMI ค่า lab ต่างๆ
-- แยกจาก vitalSign เพื่อไม่ให้ table ที่ query หนัก (cron, realtime) บวม
-- รองรับการผูกกับ checklist task ผ่าน task_log_id

CREATE TABLE IF NOT EXISTS public.resident_measurements (
  id              BIGSERIAL PRIMARY KEY,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  -- Context: ใครวัด ของใคร ที่ไหน เมื่อไหร่
  resident_id     BIGINT NOT NULL REFERENCES public.residents(id),
  nursinghome_id  BIGINT NOT NULL,
  recorded_by     UUID NOT NULL,              -- staff ที่กรอกข้อมูล
  recorded_at     TIMESTAMPTZ NOT NULL,       -- เวลาจริงที่วัด (อาจต่างจาก created_at)

  -- ค่าที่วัด
  measurement_type TEXT NOT NULL CHECK (measurement_type IN (
    'weight',           -- น้ำหนัก (kg)
    'height',           -- ส่วนสูง (cm)
    'bmi',              -- BMI (คำนวณได้ แต่เก็บ snapshot ไว้ด้วย)
    'hba1c',            -- HbA1c (%)
    'cholesterol',      -- Total cholesterol (mg/dL)
    'hdl',              -- HDL cholesterol (mg/dL)
    'ldl',              -- LDL cholesterol (mg/dL)
    'triglyceride',     -- Triglyceride (mg/dL)
    'creatinine',       -- Creatinine (mg/dL)
    'egfr',             -- eGFR (mL/min/1.73m²)
    'albumin',          -- Albumin (g/dL)
    'hemoglobin',       -- Hemoglobin (g/dL)
    'fasting_glucose'   -- Fasting glucose (mg/dL)
  )),
  numeric_value   DECIMAL(10,2) NOT NULL,     -- ค่าที่วัดได้
  unit            TEXT NOT NULL,              -- หน่วย: 'kg', 'cm', '%', 'mg/dL', 'g/dL', 'mL/min'

  -- ที่มาของข้อมูล: กรอกตอนไหน / จากอะไร
  source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN (
    'admission',    -- กรอกตอนแรกรับ
    'task',         -- มาจาก checklist task
    'manual',       -- staff กรอกเอง
    'lab_import'    -- นำเข้าจาก lab report ภายนอก
  )),

  -- ผูกกับ task system (เฉพาะเมื่อ source = 'task')
  -- pattern เดียวกับ vital_sign_photo.task_log_id
  task_log_id     BIGINT REFERENCES public."A_Task_logs_ver2"(id) ON DELETE SET NULL,

  -- ข้อมูลเสริม
  notes           TEXT,                       -- หมายเหตุ
  photo_url       TEXT,                       -- รูปตาชั่ง / lab report
  lab_report_date DATE,                       -- วันที่บน lab report (อาจต่างจาก recorded_at)
  is_deleted      BOOLEAN DEFAULT FALSE       -- soft delete
);

-- ============================================
-- Indexes
-- ============================================

-- Query หลัก: กราฟน้ำหนักตามเวลา (resident + type + เรียงตามวัน)
CREATE INDEX idx_rm_resident_type_date
  ON public.resident_measurements(resident_id, measurement_type, recorded_at DESC);

-- Dashboard: ดูค่าล่าสุดทุก resident ใน nursinghome
CREATE INDEX idx_rm_nursinghome
  ON public.resident_measurements(nursinghome_id, measurement_type);

-- หา measurement ที่ผูกกับ task (partial index เฉพาะที่มี task_log_id)
CREATE INDEX idx_rm_task_log
  ON public.resident_measurements(task_log_id)
  WHERE task_log_id IS NOT NULL;

-- ============================================
-- RLS Policies
-- ============================================
-- ใช้ pattern เดียวกับ table อื่นๆ: nursinghome_id = get_current_user_nursinghome_id()

ALTER TABLE public.resident_measurements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rm_select_same_nh" ON public.resident_measurements
  FOR SELECT TO authenticated
  USING (nursinghome_id = public.get_current_user_nursinghome_id());

CREATE POLICY "rm_insert_same_nh" ON public.resident_measurements
  FOR INSERT TO authenticated
  WITH CHECK (nursinghome_id = public.get_current_user_nursinghome_id());

CREATE POLICY "rm_update_same_nh" ON public.resident_measurements
  FOR UPDATE TO authenticated
  USING (nursinghome_id = public.get_current_user_nursinghome_id());

CREATE POLICY "rm_service_role" ON public.resident_measurements
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ============================================
-- View: ค่าล่าสุดของแต่ละ resident แต่ละ measurement_type
-- ============================================
-- ใช้ DISTINCT ON เพื่อดึงแถวล่าสุดของแต่ละคู่ (resident, type)
-- เหมาะสำหรับแสดงใน dashboard หรือ resident detail

CREATE OR REPLACE VIEW public.resident_latest_measurements AS
SELECT DISTINCT ON (rm.resident_id, rm.measurement_type)
  rm.id,
  rm.resident_id,
  rm.nursinghome_id,
  rm.measurement_type,
  rm.numeric_value,
  rm.unit,
  rm.recorded_at,
  rm.source,
  rm.recorded_by
FROM public.resident_measurements rm
WHERE rm.is_deleted = FALSE
ORDER BY rm.resident_id, rm.measurement_type, rm.recorded_at DESC;

-- ============================================
-- Function: คำนวณ BMI จาก weight + height ล่าสุด
-- ============================================
-- BMI = weight(kg) / height(m)²
-- คืน NULL ถ้าไม่มี weight หรือ height

CREATE OR REPLACE FUNCTION public.get_resident_bmi(p_resident_id BIGINT)
RETURNS DECIMAL(4,1)
LANGUAGE sql
STABLE
AS $$
  SELECT ROUND(
    (
      SELECT numeric_value
      FROM public.resident_measurements
      WHERE resident_id = p_resident_id
        AND measurement_type = 'weight'
        AND is_deleted = FALSE
      ORDER BY recorded_at DESC
      LIMIT 1
    )
    /
    POWER(
      (
        SELECT numeric_value / 100.0  -- แปลง cm เป็น m
        FROM public.resident_measurements
        WHERE resident_id = p_resident_id
          AND measurement_type = 'height'
          AND is_deleted = FALSE
        ORDER BY recorded_at DESC
        LIMIT 1
      ),
      2
    ),
    1
  )::DECIMAL(4,1);
$$;
