// What supabase/console2.sql reads, applied before it in a test's Postgres
// (db2_check.mjs, api2_check.mjs).
export const NEEDS = ["supabase/feedback.sql", "supabase/beta_join.sql", "supabase/console.sql", "supabase/relay.sql",
  "supabase/admission_snapshots.sql", "tests/fixtures/console/cron_runs.sql"];
