// pastereview: delete the throwaway accounts named on the command line (runs stopped by hand).
//   node tools/web/pastereview_cleanup.mjs EMAIL...
import { deleteAccount } from "./session.mjs";

for (const email of process.argv.slice(2)) {
  if (!/^delivered\+bw-[a-z0-9-]+@resend\.dev$/.test(email)) {
    console.log(`skipped (not a throwaway): ${email}`);
    continue;
  }
  console.log(`${email}: ${await deleteAccount(email).catch((e) => `failed: ${e.message}`)}`);
}
