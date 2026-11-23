// Make a minifig (avatarkit, 2026-11-23): Edit profile's maker of a
// minifigure of real parts as your avatar, beside Choose a picture (the
// owner: "a brickworks avatar generator that is obviously lego minifig
// themed ... they should still obviously have the option to upload their
// own image"). A face, hair or a hat and its colour, a torso's print and
// colour, the legs' colour and the background, each a choice of radio
// buttons whose every tile is your figure with that choice made; Surprise me
// for a figure at random; the figure as it will be shown, at a byline's, a
// card's and a profile's size, on a light page and a dark one. Save draws it
// as one picture, from the same layers every page lays it from (web/card.js
// MINIFIG), and gives it back with its recipe for web/profile.js to keep as
// your picture (api/_avatars.js); Cancel or Escape keeps what you had.
import { MINIFIG, minifigHtml, minifigLayers, say } from "/card.js";

// Each choice's name, said to a screen reader and as a tile's title: in the
// lists' order (web/card.js MINIFIG), as literal words for the translations.
const NAMES = () => ({
  faces: [say("Classic grin"), say("Smile"), say("Smile with lips"), say("Raised eyebrow"), say("Glasses"),
    say("Beard"), say("Sunglasses"), say("Freckles"), say("Moustache"), say("Big smile")],
  hair: [say("Short hair"), say("Long wavy hair"), say("Ponytail"), say("Bob"), say("Spiky hair"), say("Curly hair"),
    say("Swept hair"), say("Long straight hair"), say("Knit cap"), say("Hard hat"), say("Fedora"), say("Top hat"),
    say("Peaked cap"), say("Flat cap"), say("No hair")],
  hairColours: [say("Black"), say("Dark brown"), say("Brown"), say("Blond"), say("Auburn"), say("Grey")],
  prints: [say("Plain"), say("Zip jacket"), say("Suit and tie"), say("Knit jumper"), say("Dungarees"),
    say("Jacket and shirt"), say("Diagonal zip"), say("Tie")],
  colours: [say("Red"), say("Blue"), say("Green"), say("Yellow"), say("Black"), say("White"), say("Dark grey"),
    say("Orange"), say("Dark blue"), say("Dark red"), say("Azure"), say("Lavender")],
  backgrounds: [say("Red"), say("Blue"), say("Green"), say("Purple"), say("Amber"), say("Teal"), say("Berry"), say("Grey")],
});

// The LDraw colours' own, as the layers draw them (assets/generated/colors.json).
const RGB = { 0: "#1b2a34", 1: "#1e5aa8", 2: "#00852b", 4: "#b40000", 14: "#fac80a", 15: "#f4f4f4", 19: "#d7ba8c",
  25: "#d67923", 30: "#a06eb9", 70: "#5f3109", 71: "#969696", 72: "#646464", 272: "#19325a", 308: "#352100",
  320: "#720012", 322: "#68c3e2", 484: "#91501c" };

// The groups, in the order a person makes a figure: [key in the recipe,
// heading, the list, how a tile draws ("face": your figure with it, close
// up; "bust": head and shoulders; a colour's swatch otherwise)].
const GROUPS = () => [
  ["face", say("Face"), MINIFIG.faces, "face", "faces"],
  ["hair", say("Hair or hat"), MINIFIG.hair, "face", "hair"],
  ["hairColour", say("Hair colour"), MINIFIG.hairColours, "swatch", "hairColours"],
  ["print", say("Torso"), MINIFIG.prints, "bust", "prints"],
  ["torso", say("Torso colour"), MINIFIG.colours, "swatch", "colours"],
  ["legs", say("Legs colour"), MINIFIG.colours, "swatch", "colours"],
  ["background", say("Background"), MINIFIG.backgrounds.map((_, at) => at + 1), "ground", "backgrounds"],
];

const pick = (list) => list[Math.floor(Math.random() * list.length)];

/// A minifigure at random, from every list.
export function surprise() {
  return { v: 1, face: pick(MINIFIG.faces), hair: pick(MINIFIG.hair.filter(Boolean)), hairColour: pick(MINIFIG.hairColours),
    print: pick(MINIFIG.prints), torso: pick(MINIFIG.colours), legs: pick(MINIFIG.colours),
    background: 1 + Math.floor(Math.random() * MINIFIG.backgrounds.length) };
}

function loaded(src) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`no ${src}`));
    image.src = src;
  });
}

/// [recipe] drawn as one square PNG, as its layers lie on every page:
/// {blob, side}.
export async function minifigPicture(recipe) {
  const side = MINIFIG.sizes.at(-1);
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = side;
  const c = canvas.getContext("2d");
  c.fillStyle = MINIFIG.backgrounds[recipe.background - 1];
  c.fillRect(0, 0, side, side);
  for (const src of minifigLayers(recipe, side).reverse()) c.drawImage(await loaded(src), 0, 0, side, side);
  const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
  if (!blob) throw new Error(say("That minifig would not draw: try again."));
  return { blob, side };
}

/// The maker in [dialog] (web/profile.html #minifig-dialog), starting from
/// [start]: resolves {recipe, blob} once Save has drawn it, or null when it
/// is closed without saving.
export function makeMinifig(dialog, start) {
  const $ = (id) => dialog.querySelector(`#${id}`);
  const names = NAMES();
  let recipe = { ...start };
  const groups = GROUPS();
  const choices = $("minifig-choices");
  choices.innerHTML = groups.map(([key, heading, list, how, named]) => `<fieldset class="minifig-group" data-key="${key}">`
    + `<legend>${heading}</legend><div class="minifig-tiles ${how}">${list.map((value, at) => {
      const name = names[named][at];
      return `<label class="minifig-tile" title="${name}"><input type="radio" name="minifig-${key}" value="${at}">`
        + `<span class="tile" data-at="${at}"></span><span class="visually-hidden">${name}</span></label>`;
    }).join("")}</div></fieldset>`).join("");

  // Every tile and the look drawn for the figure as it is now.
  const draw = () => {
    for (const [key, , list, how] of groups) {
      const group = choices.querySelector(`[data-key="${key}"]`);
      group.hidden = key === "hairColour" && (!recipe.hair || MINIFIG.hats[recipe.hair] !== undefined);
      for (const tile of group.querySelectorAll(".tile")) {
        const value = list[Number(tile.dataset.at)];
        if (how === "face" || how === "bust") {
          tile.innerHTML = minifigHtml({ ...recipe, [key]: value }, { size: how === "bust" ? "big" : "" });
        } else if (how === "swatch") {
          tile.style.background = RGB[value];
        } else {
          tile.style.background = MINIFIG.backgrounds[value - 1];
        }
        const input = tile.previousElementSibling;
        input.checked = value === recipe[key];
      }
    }
    $("minifig-big").outerHTML = minifigHtml(recipe, { size: "huge", id: "minifig-big" });
    const sizes = minifigHtml(recipe, { size: "small" }) + minifigHtml(recipe) + minifigHtml(recipe, { size: "big" });
    $("minifig-light").innerHTML = sizes;
    $("minifig-dark").innerHTML = sizes;
  };
  const changed = (event) => {
    const input = event.target.closest("input[type=radio]");
    if (!input) return;
    const [key, , list] = groups.find(([one]) => input.name === `minifig-${one}`);
    recipe = { ...recipe, [key]: list[Number(input.value)] };
    draw();
  };
  draw();
  $("minifig-note").textContent = "";

  return new Promise((resolve) => {
    let saving = false;
    const surprised = () => { recipe = surprise(); draw(); };
    const cancel = () => dialog.close();
    const save = async () => {
      if (saving) return;
      saving = true;
      $("minifig-save").disabled = true;
      $("minifig-note").textContent = say("Drawing your minifig…");
      try {
        const { blob } = await minifigPicture(recipe);
        end({ recipe, blob });
      } catch (trouble) {
        $("minifig-note").textContent = String(trouble?.message || say("That minifig would not draw: try again."));
      } finally {
        saving = false;
        $("minifig-save").disabled = false;
      }
    };
    let made = null;
    const closed = () => end(made);
    function end(result) {
      made = result;
      choices.removeEventListener("change", changed);
      $("minifig-surprise").removeEventListener("click", surprised);
      $("minifig-cancel").removeEventListener("click", cancel);
      $("minifig-save").removeEventListener("click", save);
      dialog.removeEventListener("close", closed);
      if (dialog.open) dialog.close();
      resolve(result);
    }
    choices.addEventListener("change", changed);
    $("minifig-surprise").addEventListener("click", surprised);
    $("minifig-cancel").addEventListener("click", cancel);
    $("minifig-save").addEventListener("click", save);
    dialog.addEventListener("close", closed);
    dialog.showModal();
    choices.querySelector("input:checked")?.focus();
  });
}
