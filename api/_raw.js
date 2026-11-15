// A request's body exactly as it was sent, for a webhook whose signature is
// made over its bytes: Admission's (api/plans.js) and Resend's
// (api/_console_mail.js).

/// The body exactly as sent, as a signature is made over it, or null past
/// [most] bytes. Vercel's helpers parse a JSON body, which loses its bytes,
/// and leave them to read again as the request's data (@vercel/node
/// restoreBody); a request made here with a string body is that string.
export function rawOf(request, most = 256 * 1024) {
  if (typeof request.on !== "function") return Promise.resolve(typeof request.body === "string" ? request.body : null);
  return new Promise((done) => {
    const chunks = [];
    let size = 0;
    const timer = setTimeout(() => done(null), 5000);
    request.on("data", (chunk) => {
      size += chunk.length;
      if (size <= most) chunks.push(Buffer.from(chunk));
    });
    request.on("end", () => {
      clearTimeout(timer);
      done(size > most ? null : Buffer.concat(chunks).toString("utf8"));
    });
    request.on("error", () => {
      clearTimeout(timer);
      done(null);
    });
  });
}
