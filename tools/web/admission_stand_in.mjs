// The stand-in Admission (tests/fixtures/billing/fake_admission.mjs) on
// this machine, for the site's functions to ask over HTTP, and the two
// things only a test does: a person pays, or cancels, and Admission's signed
// webhook goes to the site, as Admission sends it once Stripe has said so.
//
//   node tools/web/admission_stand_in.mjs 8891 --hook=http://127.0.0.1:8890/api/plans?op=webhook &
//   BRICKWORKS_BILLING=test ADMISSION_KEY=adm_test_00000000000000000000000000000000 \
//     ADMISSION_URL=http://127.0.0.1:8891 ADMISSION_WEBHOOK_SECRET=adm_whsec_standin0000000000000000000000 \
//     node --env-file=.env tools/web/relay_server.mjs 8890 --hold=plan_consents &
//
//   POST /__stand_in/pay     {customerId, interval}  Pro, renewing
//   POST /__stand_in/cancel  {customerId}            Pro until the period's end
//   POST /__stand_in/erased  {customerId}            {erasures}: each time the
//                                                     site erased them
//
// The first two answer {heard}, the site's answer to the webhook. Everything else is
// Admission's API as the stand-in answers it. A unit's preview has no such
// server: there the stand-in answers in the function's own process
// (api/_billing.js), and nobody can pay.
import http from "node:http";
import { fakeAdmission, signWebhook } from "../../tests/fixtures/billing/fake_admission.mjs";

const port = Number(process.argv[2] || 8891);
const hook = (process.argv.find((a) => a.startsWith("--hook=")) || "").slice(7);
const admission = fakeAdmission();
let seq = 0;

/// Admission's word that [customerId]'s answer changed, signed, to the site.
async function tell(customerId, reason) {
  if (!hook) return { error: "no --hook" };
  seq += 1;
  const customer = await (await admission.fetch(`https://admission.test/v1/customers/${encodeURIComponent(customerId)}`,
    { headers: { authorization: "Bearer adm_test_00000000000000000000000000000000" } })).json();
  const body = JSON.stringify({ id: `adm_evt_standin_${Date.now()}_${seq}`, type: "customer.updated",
    createdAt: new Date().toISOString(), mode: "test", seq, data: { customerId, reason, customer } });
  const sent = await fetch(hook, { method: "POST", body,
    headers: { "content-type": "application/json", "admission-signature": await signWebhook(body) } });
  return { status: sent.status, ...(await sent.json().catch(() => ({}))) };
}

http.createServer(async (incoming, outgoing) => {
  const chunks = [];
  for await (const chunk of incoming) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString();
  const url = new URL(incoming.url, `http://127.0.0.1:${port}`);
  const reply = (status, value) => {
    outgoing.writeHead(status, { "content-type": "application/json" });
    outgoing.end(JSON.stringify(value));
  };
  if (incoming.method === "POST" && url.pathname.startsWith("/__stand_in/")) {
    const asked = JSON.parse(raw || "{}");
    const customerId = String(asked.customerId || "");
    if (!customerId) return reply(422, { error: "customerId" });
    if (url.pathname === "/__stand_in/pay") {
      admission.subscribe(customerId, { interval: asked.interval === "year" ? "year" : "month" });
      return reply(200, { heard: await tell(customerId, "subscription.created") });
    }
    if (url.pathname === "/__stand_in/erased") {
      return reply(200, { erasures: admission.erasures.filter((e) => e.customerId === customerId) });
    }
    if (url.pathname === "/__stand_in/cancel") {
      const later = new Date(Date.now() + 30 * 86400000).toISOString();
      admission.subscribe(customerId, { currentPeriodEnd: later, endsAt: later });
      return reply(200, { heard: await tell(customerId, "subscription.changed") });
    }
    return reply(404, { error: "no such thing" });
  }
  const answer = await admission.fetch(`https://admission.test${url.pathname}${url.search}`,
    { method: incoming.method, headers: incoming.headers, body: raw || undefined });
  outgoing.writeHead(answer.status, { "content-type": "application/json" });
  outgoing.end(await answer.text());
}).listen(port, "127.0.0.1", () => console.log(`the stand-in Admission on http://127.0.0.1:${port}`));
