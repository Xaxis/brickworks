// A busy Talk, for the stand-in's world (tools/web/talk_stand_in.mjs with
// --talk-crowd): forty builders of this world alone, 560 threads over the
// last four months, Help's 500 of them, and one Show and tell thread of
// 200 posts, so a check can page a board and a long thread and time them
// (tools/web/talk_pages_check.mjs, unit talk2) and a walk can see Talk as a
// forum people use every day looks. Made-up people, in this machine's
// Postgres only: never the project's, never shown to anybody.
//
// The same every run (a seeded random), dated back from the moment it is
// made, in the people's pool (test false), so /talk shows it as it is.

/// A random of its own, the same each time: [0, 1).
function seeded(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const FIRST = ["Ada", "Ben", "Cleo", "Dev", "Elif", "Finn", "Gus", "Hana", "Ivo", "Jun", "Kai", "Lena", "Milo", "Nia",
  "Omar", "Pia", "Quin", "Rosa", "Sami", "Tove", "Uma", "Vik", "Wren", "Xia", "Yusuf", "Zoe", "Arlo", "Bea", "Cyrus",
  "Dara", "Emil", "Fern", "Gio", "Hugo", "Isla", "Jory", "Kit", "Luca", "Mae", "Noor"];
const LAST = ["Brick", "Stud", "Plate", "Tile", "Hinge", "Slope", "Axle", "Gear", "Panel", "Arch"];

const HELP = [
  "How do I join two plates at a right angle?", "Best way to build a curved wall in the studio?",
  "Why does my wing droop when I attach it with a single hinge?", "Which part makes a 45 degree roof corner?",
  "Snapping a Technic beam to a stud: is it legal?", "Stuck on step {n} of my castle gate",
  "How do people do SNOT bricks for a smooth car side?", "My tower leans after step {n}: what holds it straight?",
  "What is the strongest way to mount a minifig on a horse?", "Colour for a weathered roof: dark tan or sand green?",
  "How to make a round window without a round brick?", "The studio will not let me rotate a part by 22.5 degrees",
  "Exploded steps look wrong on my phone", "How many studs wide should a city tram be?",
  "Getting a 1 x 2 jumper to sit half a stud over", "Tips for building a sturdy Technic gearbox?",
];
const SHOW = [
  "My windmill with turning sails", "A tiny lighthouse at microscale", "Harbour tug, finished at last",
  "Work in progress: a Victorian station", "Moon base with a working airlock", "Fishing village diorama",
  "Steam locomotive in eight wide", "A chip shop on the corner", "Mech with a posable hip",
  "Treehouse for the challenge", "My first Technic crane", "Space shuttle, studs-up version",
];
const IDEAS = ["A parts list I can print beside the steps", "Let us vote on next month's challenge",
  "Dark mode for the step player", "Show how many of each part I own when I open a model",
  "A board for train builders", "Swap parts with other builders nearby"];
const WORDS = [
  "Try a bracket under the plate and turn it on its side.", "I had the same trouble: a hinge brick and a plate on top fixed it.",
  "Thanks, that worked!", "Could you share a link to the step?", "Here is how I did mine: two clips and a bar.",
  "That colour reads much better in the photo.", "Lovely work on the roof line.",
  "The trick is to brace it every four bricks with a Technic pin.", "Have you tried the curved slopes instead of steps?",
  "I would keep it 6 wide; 8 wide gets heavy for the tracks.", "Post a photo when it is done!",
  "Same here, the studio did that to me until I turned snap off.", "Great question, I wondered too.",
  "Jumper plates are your friend here.", "It holds if you clutch it from both sides.",
  "Sand green would look wonderful against the grey.", "Following this one.",
];

/// The crowd put into [db] (talkWorld's): [models] real models' ids and
/// names the project lists (their pictures show on the rows), [house] the
/// house's account or null. Returns {help, long, threads, posts}.
export async function crowdTalk(db, { models = [], house = null, now = Date.now() } = {}) {
  const random = seeded(20261127);
  const pick = (list) => list[Math.floor(random() * list.length)];
  const people = [];
  for (let at = 0; at < 40; at += 1) {
    const id = `11111111-2222-4333-8444-${String(at + 1).padStart(12, "0")}`;
    const name = `${FIRST[at]} ${LAST[at % LAST.length]}`;
    const handle = `${FIRST[at].toLowerCase()}-${LAST[at % LAST.length].toLowerCase()}`;
    people.push({ id, name, handle });
  }
  await db.q(`insert into auth.users (id, email, created_at, email_confirmed_at, last_sign_in_at)
    select (p->>'id')::uuid, (p->>'handle') || '@crowd.example', now() - interval '200 days', now() - interval '200 days', now()
      from jsonb_array_elements($1::jsonb) p on conflict (id) do nothing`, [JSON.stringify(people)]);
  await db.q(`insert into public.people (account, handle, name)
    select (p->>'id')::uuid, p->>'handle', p->>'name' from jsonb_array_elements($1::jsonb) p on conflict (account) do nothing`,
  [JSON.stringify(people)]);
  await db.q(`insert into public.profiles (id, over_13) select (p->>'id')::uuid, true from jsonb_array_elements($1::jsonb) p
    on conflict (id) do update set over_13 = true`, [JSON.stringify(people)]);
  for (const model of models) {
    await db.q(`insert into public.shared_models (id, owner, name, published, barred, listed, test, has_image, has_thumb, updated_at)
      values ($1, $2, $3, true, false, true, false, $4, $5, $6) on conflict (id) do nothing`,
    [model.id, model.owner || people[0].id, model.name, model.has_image === true, model.has_thumb === true, model.updated_at || null]);
  }
  const threads = [];
  const day = 864e5;
  const plan = [];
  for (let at = 0; at < 500; at += 1) plan.push({ board: "help", title: pick(HELP).replace("{n}", String(2 + Math.floor(random() * 40))) });
  // One live thread a model (talk_threads_one_model): the first of them each a model's.
  for (let at = 0; at < 36; at += 1) plan.push({ board: "show", title: pick(SHOW), model: at < models.length ? models[at].id : null });
  for (let at = 0; at < 24; at += 1) plan.push({ board: "ideas", title: pick(IDEAS) });
  // Oldest first, so the ids run with the dates as a forum's do.
  const ages = plan.map(() => random() * 120 * day).sort((a, b) => b - a);
  const posts = [];
  plan.forEach((one, i) => {
    const by = pick(people);
    const at = now - ages[i];
    // Most threads a handful of replies; some none; Show and tell's first
    // its 200 (the long one a check pages).
    const long = one.board === "show" && !threads.some((t) => t.long);
    const replies = long ? 199 : random() < 0.18 ? 0 : 1 + Math.floor(random() * random() * 30);
    const thread = { board: one.board, title: one.title, author: by.id, at, model: one.model || null, long, replies };
    threads.push(thread);
  });
  // Threads first, then their posts, in two statements each.
  const made = await db.q(`insert into public.talk_threads (board, title, author, at, last_at, model, test)
    select t->>'board', t->>'title', (t->>'author')::uuid, to_timestamp((t->>'at')::double precision / 1000),
           to_timestamp((t->>'at')::double precision / 1000), nullif(t->>'model', ''), false
      from jsonb_array_elements($1::jsonb) with ordinality as x(t, n) order by n
    returning id::int as id`, [JSON.stringify(threads.map((t) => ({ ...t, model: t.model || "" })))]);
  made.forEach((row, i) => { threads[i].id = row.id; });
  for (const thread of threads) {
    const words = thread.board === "help" ? `I am building ${pick(SHOW).toLowerCase()} and got stuck. ${pick(WORDS)} Any ideas?`
      : thread.board === "ideas" ? `It would help a lot when building at home. ${pick(WORDS)}` : `Finished this one last weekend. ${pick(WORDS)}`;
    posts.push({ thread: thread.id, author: thread.author, body: words, first: true, at: thread.at });
    let when = thread.at;
    const span = Math.min(now - thread.at, 30 * day);
    for (let n = 0; n < thread.replies; n += 1) {
      when = Math.min(now - 60000, when + (span / (thread.replies + 1)) * (0.5 + random()));
      const by = thread.long ? people[n % people.length] : pick(people);
      posts.push({ thread: thread.id, author: by.id, body: `${pick(WORDS)}${thread.long ? ` (${n + 2})` : ""}`, first: false, at: when });
    }
    thread.last = when;
  }
  for (let from = 0; from < posts.length; from += 2000) {
    await db.q(`insert into public.talk_posts (thread, author, body, first, at)
      select (p->>'thread')::bigint, (p->>'author')::uuid, p->>'body', (p->>'first')::boolean,
             to_timestamp((p->>'at')::double precision / 1000)
        from jsonb_array_elements($1::jsonb) with ordinality as x(p, n) order by n`, [JSON.stringify(posts.slice(from, from + 2000))]);
  }
  await db.q(`update public.talk_threads t set last_at = x.last from (select thread, max(at) as last from public.talk_posts group by thread) x
    where x.thread = t.id`);
  await db.q(`insert into public.talk_follows (account, thread) select author, thread from public.talk_posts on conflict do nothing`);
  // Views (talk2.sql), about twelve a reply and a few of their own; and the
  // starters of a fifth of Help's answered threads marked an answer.
  await db.q(`update public.talk_threads t set views = 3 + (select count(*) from public.talk_posts p where p.thread = t.id) * 12
    + (t.id * 7919) % 40`);
  await db.q(`update public.talk_threads t set answer = x.id, answered_at = x.at + interval '1 hour'
    from (select distinct on (p.thread) p.thread, p.id, p.at from public.talk_posts p join public.talk_threads k on k.id = p.thread
           where k.board = 'help' and not p.first and k.id % 5 = 0 order by p.thread, p.at, p.id) x where x.thread = t.id`);
  if (house) {
    await db.q(`insert into public.talk_threads (board, title, author, at, last_at, seed, test, pinned_at)
      values ('news', 'Welcome to Talk', $1, now() - interval '5 days', now() - interval '5 days', 'welcome', false, now())
      on conflict do nothing`, [house]);
    await db.q(`insert into public.talk_posts (thread, author, body, first, at)
      select t.id, $1, 'Talk is where builders on Brickworks talk about anything, not only under one model.', true, t.at
        from public.talk_threads t where t.seed = 'welcome' and not t.test
         and not exists (select 1 from public.talk_posts p where p.thread = t.id)`, [house]);
  }
  const long = threads.find((t) => t.long);
  return { help: 500, long: long?.id || null, threads: threads.length, posts: posts.length, people };
}
