-- Seed shift badges สำหรับแจกตอน clock-out
-- Badge เหล่านี้ได้จากการเปรียบเทียบ performance กับ staff คนอื่นในเวรเดียวกัน
-- ได้ซ้ำได้ทุกเวร (season_id = NULL ใน training_user_badges)

INSERT INTO training_badges (name, description, icon, category, rarity, points, requirement_type, requirement_value, is_active)
VALUES
  -- shift_most_completed: ทำ task เสร็จมากที่สุดในเวร
  (
    'Task Master',
    'ทำงานเสร็จเยอะที่สุดในเวร ขยันมาก!',
    '⚡',
    'shift',
    'rare',
    15,
    'shift_most_completed',
    '{}',
    true
  ),
  -- shift_most_problems: เจอปัญหามากที่สุดในเวร
  (
    'Eagle Eye',
    'เจอและรายงานปัญหามากที่สุดในเวร ตาดีมาก!',
    '🦅',
    'shift',
    'rare',
    15,
    'shift_most_problems',
    '{}',
    true
  ),
  -- shift_most_kindness: ช่วยดูแล resident ที่ไม่ใช่ของตัวเอง
  (
    'Kind Heart',
    'ช่วยดูแลผู้พักอาศัยที่ไม่ได้รับมอบหมายมากที่สุด น่ารักมาก!',
    '💖',
    'shift',
    'epic',
    25,
    'shift_most_kindness',
    '{}',
    true
  ),
  -- shift_best_timing: ทำงานตรงเวลาที่สุด
  (
    'Perfect Timing',
    'ทำงานตรงเวลากำหนดมากที่สุดในเวร แม่นยำมาก!',
    '⏰',
    'shift',
    'epic',
    25,
    'shift_best_timing',
    '{}',
    true
  ),
  -- shift_most_dead_air: Dead air มากที่สุด (badge ตลก/กระตุ้น)
  (
    'Chill Mode',
    'มีช่วงเวลาว่างมากที่สุดในเวร... พักผ่อนเยอะจัง!',
    '😴',
    'shift',
    'common',
    5,
    'shift_most_dead_air',
    '{}',
    true
  ),
  -- shift_novice_rating: ให้คะแนนความยากสูงกว่า norm
  (
    'Newbie Vibes',
    'ประเมินงานว่ายากกว่าค่าเฉลี่ย ยังอยู่ในช่วงเรียนรู้!',
    '🤔',
    'shift',
    'common',
    5,
    'shift_novice_rating',
    '{"min_diff_sum": 10}',
    true
  ),
  -- shift_master_rating: ให้คะแนนความยากต่ำกว่า norm
  (
    'Pro Player',
    'ประเมินงานว่าง่ายกว่าค่าเฉลี่ย มือเก๋ามากแม่!',
    '🎓',
    'shift',
    'rare',
    15,
    'shift_master_rating',
    '{"min_diff_sum": 10}',
    true
  );
