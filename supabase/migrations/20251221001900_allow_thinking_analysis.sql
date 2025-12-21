-- Allow all authenticated users to read training_quiz_answers for thinking analysis view
-- This is needed because the view uses security_invoker='on'

-- Drop existing restrictive policy
DROP POLICY IF EXISTS "own_answers" ON "public"."training_quiz_answers";

-- Create new policy that allows authenticated users to read all answers
CREATE POLICY "read_all_answers" ON "public"."training_quiz_answers"
FOR SELECT
TO authenticated
USING (true);

-- Keep insert/update/delete restricted to own answers
CREATE POLICY "manage_own_answers" ON "public"."training_quiz_answers"
FOR ALL
TO authenticated
USING (EXISTS (
  SELECT 1 FROM training_quiz_sessions
  WHERE training_quiz_sessions.id = training_quiz_answers.session_id
  AND training_quiz_sessions.user_id = auth.uid()
))
WITH CHECK (EXISTS (
  SELECT 1 FROM training_quiz_sessions
  WHERE training_quiz_sessions.id = training_quiz_answers.session_id
  AND training_quiz_sessions.user_id = auth.uid()
));
