## A part's name, and a colour's, in German, French or Spanish, as LEGO's own
## sites and instructions word them: "Brique 1×2", "Plaque lisse 1×4 avec
## rainure", "Gris bleuté clair".
##
## LDraw names a part by a formula: its kind ("Brick", "Hinge Plate",
## "Technic Beam"), its size as builders write it (1×2, 45, 15), and then
## what sets it apart, an adjective (Round, Inverted, Curved) or a noun after
## "with", "without", "on" or "for" ("with Groove", "with 2 Studs on 1
## Side"). So a part is said through a glossary of those words, never a list
## of parts: the kind is the language's noun, the adjectives agree with it
## as French and Spanish make them (Brique ronde, Ladrillo redondo) and stand
## after it as a German list puts them (Stein 2×2 rund), the nouns after a
## preposition take their number and German its case (mit 2 Löchern, ohne
## untere Röhre), and every number and size stays as it was written.
##
## A name the glossary cannot word whole stays as LDraw wrote it, in
## English, never half in each: a print's or a sticker's says what it
## pictures, a minifigure's who it is. A colour likewise, by its words
## (Trans, Pearl; Light, Dark; Bluish; Red, Grey), and a colour named with
## its finish ("Red, solid") is said whole or not at all (Language).
##
## And read back for a search (spoken): each of the language's words, in
## each of its forms and without its accents, with LDraw's beside it, so
## "brique 1x2" finds 3004 while "brick 1x2" and "3004" still do.
class_name PartWords
extends RefCounted

## The languages, by their place in each entry's translations.
const LANGUAGES: Dictionary = {"de": 0, "fr": 1, "es": 2}

## A part's kind, what its name begins with: German's noun, and French's
## and Spanish's with its gender after a bar, which the words after it
## agree with.
const KINDS: Dictionary = {
	"brick": ["Stein", "Brique|f", "Ladrillo|m"],
	"plate": ["Platte", "Plaque|f", "Placa|f"],
	"tile": ["Fliese", "Plaque lisse|f", "Baldosa|f"],
	"slope": ["Dachstein", "Brique inclinée|f", "Teja|f"],
	"slope brick": ["Dachstein", "Brique inclinée|f", "Teja|f"],
	"wedge": ["Keil", "Biseau|m", "Cuña|f"],
	"wedge plate": ["Keilplatte", "Plaque biseautée|f", "Placa en cuña|f"],
	"panel": ["Paneel", "Panneau|m", "Panel|m"],
	"bracket": ["Winkel", "Équerre|f", "Escuadra|f"],
	"arch": ["Bogen", "Arche|f", "Arco|m"],
	"hinge": ["Scharnier", "Charnière|f", "Bisagra|f"],
	"hinge plate": ["Scharnierplatte", "Plaque charnière|f", "Placa bisagra|f"],
	"hinge brick": ["Scharnierstein", "Brique charnière|f", "Ladrillo bisagra|m"],
	"window": ["Fenster", "Fenêtre|f", "Ventana|f"],
	"door": ["Tür", "Porte|f", "Puerta|f"],
	"door frame": ["Türrahmen", "Cadre de porte|m", "Marco de puerta|m"],
	"wheel": ["Rad", "Roue|f", "Rueda|f"],
	"wheel rim": ["Felge", "Jante|f", "Llanta|f"],
	"tyre": ["Reifen", "Pneu|m", "Neumático|m"],
	"baseplate": ["Grundplatte", "Plaque de base|f", "Placa base|f"],
	"cylinder": ["Zylinder", "Cylindre|m", "Cilindro|m"],
	"cone": ["Kegel", "Cône|m", "Cono|m"],
	"dish": ["Schüssel", "Parabole|f", "Parabólica|f"],
	"bar": ["Stange", "Barre|f", "Barra|f"],
	"beam": ["Lochbalken", "Poutre|f", "Viga|f"],
	"liftarm": ["Lochbalken", "Poutre|f", "Viga|f"],
	"axle": ["Achse", "Essieu|m", "Eje|m"],
	"gear": ["Zahnrad", "Engrenage|m", "Engranaje|m"],
	"gear rack": ["Zahnstange", "Crémaillère|f", "Cremallera|f"],
	"pin": ["Pin", "Cheville|f", "Pasador|m"],
	"bush": ["Buchse", "Bague|f", "Casquillo|m"],
	"connector": ["Verbinder", "Connecteur|m", "Conector|m"],
	"cross block": ["Kreuzblock", "Bloc croisé|m", "Bloque cruzado|m"],
	"shock absorber": ["Stoßdämpfer", "Amortisseur|m", "Amortiguador|m"],
	"pneumatic cylinder": ["Pneumatikzylinder", "Vérin pneumatique|m", "Cilindro neumático|m"],
	"pneumatic pump": ["Pneumatikpumpe", "Pompe pneumatique|f", "Bomba neumática|f"],
	"linear actuator": ["Linearaktuator", "Vérin linéaire|m", "Actuador lineal|m"],
	"suspension arm": ["Querlenker", "Bras de suspension|m", "Brazo de suspensión|m"],
	"wing": ["Flügel", "Aile|f", "Ala|f"],
	"windscreen": ["Windschutzscheibe", "Pare-brise|m", "Parabrisas|m"],
	"support": ["Stütze", "Support|m", "Soporte|m"],
	"container": ["Behälter", "Conteneur|m", "Contenedor|m"],
	"turntable": ["Drehscheibe", "Plateau tournant|m", "Plataforma giratoria|f"],
	"dome": ["Kuppel", "Dôme|m", "Cúpula|f"],
	"fence": ["Zaun", "Clôture|f", "Valla|f"],
	"ladder": ["Leiter", "Échelle|f", "Escalera|f"],
	"rock": ["Fels", "Rocher|m", "Roca|f"],
	"tube": ["Rohr", "Tube|m", "Tubo|m"],
	"box": ["Kiste", "Boîte|f", "Caja|f"],
	"bucket": ["Eimer", "Seau|m", "Cubo|m"],
	"propeller": ["Propeller", "Hélice|f", "Hélice|f"],
	"magnet": ["Magnet", "Aimant|m", "Imán|m"],
	"antenna": ["Antenne", "Antenne|f", "Antena|f"],
	"roof": ["Dach", "Toit|m", "Tejado|m"],
	"lever": ["Hebel", "Levier|m", "Palanca|f"],
	"ring": ["Ring", "Anneau|m", "Anillo|m"],
	"cockpit": ["Cockpit", "Cockpit|m", "Cabina|f"],
	"mudguard": ["Kotflügel", "Garde-boue|m", "Guardabarros|m"],
	"hook": ["Haken", "Crochet|m", "Gancho|m"],
	"chain": ["Kette", "Chaîne|f", "Cadena|f"],
	"rail": ["Schiene", "Rail|m", "Riel|m"],
	"glass": ["Glas", "Vitre|f", "Cristal|m"],
	"sphere": ["Kugel", "Sphère|f", "Esfera|f"],
	"spring": ["Feder", "Ressort|m", "Muelle|m"],
	"axle pin": ["Achs-Pin", "Cheville à essieu|f", "Pasador-eje|m"],
	"axle joiner": ["Achsverbinder", "Raccord d'essieux|m", "Unión de ejes|f"],
	"pin joiner": ["Pinverbinder", "Raccord de chevilles|m", "Unión de pasadores|f"],
	"angle connector": ["Winkelverbinder", "Connecteur d'angle|m", "Conector de ángulo|m"],
	"connector block": ["Verbinderblock", "Bloc connecteur|m", "Bloque conector|m"],
	"pneumatic tube": ["Pneumatikschlauch", "Tube pneumatique|m", "Tubo neumático|m"],
	"brick separator": ["Steintrenner", "Séparateur de briques|m", "Separador de ladrillos|m"],
	"disc": ["Scheibe", "Disque|m", "Disco|m"],
	"hose": ["Schlauch", "Tuyau|m", "Manguera|f"],
	"mast": ["Mast", "Mât|m", "Mástil|m"],
	"cupboard": ["Schrank", "Placard|m", "Armario|m"],
	"crate": ["Kiste", "Caisse|f", "Caja|f"],
	"steering wheel": ["Lenkrad", "Volant|m", "Volante|m"],
	"rotor": ["Rotor", "Rotor|m", "Rotor|m"],
	"panel fairing": ["Verkleidungspaneel", "Panneau de carénage|m", "Panel de carenado|m"],
}
## An adjective: German's as it stands after the noun and, after a slash,
## the stem it is declined from before one ("links/link": mit linker Seite;
## "" where it never stands before one); French's and Spanish's masculine,
## or all four forms (masculine, feminine, their plurals) where they are
## not made the usual way.
const ADJECTIVES: Dictionary = {
	"curved": ["gebogen", "incurvé", "curvo"],
	"round": ["rund", "rond", "redondo"],
	"inverted": ["umgekehrt", "inversé", "invertido"],
	"double": ["doppelt", "double", "doble"],
	"triple": ["dreifach", "triple", "triple"],
	"quadruple": ["vierfach", "quadruple", "cuádruple"],
	"single": ["einfach", "simple", "simple"],
	"wide": ["breit", "large", "ancho"],
	"thin": ["dünn", "fin", "fino"],
	"thick": ["dick", "épais/épaisse/épais/épaisses", "grueso"],
	"flat": ["flach", "plat", "plano"],
	"smooth": ["glatt", "lisse", "liso"],
	"reinforced": ["verstärkt", "renforcé", "reforzado"],
	"triangular": ["dreieckig", "triangulaire", "triangular"],
	"trapezoidal": ["trapezförmig", "trapézoïdal/trapézoïdale/trapézoïdaux/trapézoïdales", "trapezoidal"],
	"square": ["quadratisch", "carré", "cuadrado"],
	"rectangular": ["rechteckig", "rectangulaire", "rectangular"],
	"octagonal": ["achteckig", "octogonal/octogonale/octogonaux/octogonales", "octogonal"],
	"left": ["links/link", "gauche", "izquierdo"],
	"right": ["rechts/recht", "droit", "derecho"],
	"long": ["lang", "long/longue/longs/longues", "largo"],
	"short": ["kurz", "court", "corto"],
	"large": ["groß", "grand", "grande"],
	"small": ["klein", "petit", "pequeño"],
	"hollow": ["hohl", "creux/creuse/creux/creuses", "hueco"],
	"solid": ["massiv", "plein", "macizo"],
	"open": ["offen", "ouvert", "abierto"],
	"closed": ["geschlossen", "fermé", "cerrado"],
	"locking": ["rastend", "à crans/à crans/à crans/à crans", "de bloqueo/de bloqueo/de bloqueo/de bloqueo"],
	"angled": ["abgewinkelt", "coudé", "angulado"],
	"bent": ["abgewinkelt", "coudé", "doblado"],
	"tapered": ["verjüngt", "effilé", "ahusado"],
	"straight": ["gerade/gerad", "droit", "recto"],
	"flexible": ["flexibel/flexibl", "flexible", "flexible"],
	"offset": ["versetzt", "décalé", "desplazado"],
	"convex": ["konvex", "convexe", "convexo"],
	"concave": ["konkav", "concave", "cóncavo"],
	"rounded": ["abgerundet", "arrondi", "redondeado"],
	"sloped": ["schräg", "incliné", "inclinado"],
	"raised": ["erhöht", "surélevé", "elevado"],
	"vertical": ["senkrecht", "vertical/verticale/verticaux/verticales", "vertical"],
	"horizontal": ["waagerecht", "horizontal/horizontale/horizontaux/horizontales", "horizontal"],
	"arched": ["gewölbt", "arqué", "arqueado"],
	"recessed": ["versenkt", "encastré", "empotrado"],
	"ribbed": ["gerippt", "nervuré", "nervado"],
	"slotted": ["geschlitzt", "rainuré", "ranurado"],
	"split": ["geteilt", "fendu", "partido"],
	"fixed": ["fest", "fixe", "fijo"],
	"sliding": ["verschiebbar", "coulissant", "deslizante"],
	"stepped": ["gestuft", "étagé", "escalonado"],
	"notched": ["gekerbt", "entaillé", "entallado"],
	"inner": ["innen/inner", "intérieur", "interior"],
	"outer": ["außen/äußer", "extérieur", "exterior"],
	"upper": ["oben/ober", "supérieur", "superior"],
	"lower": ["unten/unter", "inférieur", "inferior"],
	"top": ["Oberteil/ober", "supérieur", "superior"],
	"bottom": ["Unterteil/unter", "inférieur", "inferior"],
	"front": ["vorne/vorder", "avant/avant/avant/avant", "delantero"],
	"rear": ["hinten/hinter", "arrière/arrière/arrière/arrière", "trasero"],
	"centre": ["mittig", "central/centrale/centraux/centrales", "central"],
	"center": ["mittig", "central/centrale/centraux/centrales", "central"],
	"corner": ["Ecke/", "d'angle/d'angle/d'angle/d'angle", "de esquina/de esquina/de esquina/de esquina"],
	"type": ["Typ/", "type/type/type/type", "tipo/tipo/tipo/tipo"],
	"cylindrical": ["zylindrisch", "cylindrique", "cilíndrico"],
	"conical": ["konisch", "conique", "cónico"],
	"classic": ["klassisch", "classique", "clásico"],
	"medium": ["mittel/mittler", "moyen/moyenne/moyens/moyennes", "mediano"],
	"deep": ["tief", "profond", "profundo"],
	"narrow": ["schmal", "étroit", "estrecho"],
	"tall": ["hoch/hoh", "haut", "alto"],
	"low": ["niedrig", "bas/basse/bas/basses", "bajo"],
	"high": ["hoch/hoh", "haut", "alto"],
	"perpendicular": ["senkrecht", "perpendiculaire", "perpendicular"],
	"parallel": ["parallel", "parallèle", "paralelo"],
	"dual": ["doppelt", "double", "doble"],
	"half": ["halb", "demi/demie/demis/demies", "medio"],
	"up": ["nach oben/", "vers le haut/vers le haut/vers le haut/vers le haut", "hacia arriba/hacia arriba/hacia arriba/hacia arriba"],
	"down": ["nach unten/", "vers le bas/vers le bas/vers le bas/vers le bas", "hacia abajo/hacia abajo/hacia abajo/hacia abajo"],
	"integral": ["integriert", "intégré", "integrado"],
	"soft": ["weich", "souple", "blando"],
	"stiff": ["hart", "rigide", "rígido"],
	"symmetric": ["symmetrisch", "symétrique", "simétrico"],
	"asymmetric": ["asymmetrisch", "asymétrique", "asimétrico"],
	"blind": ["blind", "borgne", "ciego"],
}
## A noun after a preposition or a count: English's plural, then each
## language's singular, plural and gender.
const NOUNS: Dictionary = {
	"hole": ["holes", "Loch|Löcher|n", "trou|trous|m", "agujero|agujeros|m"],
	"stud": ["studs", "Noppe|Noppen|f", "tenon|tenons|m", "espiga|espigas|f"],
	"groove": ["grooves", "Rille|Rillen|f", "rainure|rainures|f", "ranura|ranuras|f"],
	"pin": ["pins", "Pin|Pins|m", "cheville|chevilles|f", "pasador|pasadores|m"],
	"axle": ["axles", "Achse|Achsen|f", "essieu|essieux|m", "eje|ejes|m"],
	"axlehole": ["axleholes", "Achsloch|Achslöcher|n", "trou d'essieu|trous d'essieu|m", "agujero de eje|agujeros de eje|m"],
	"clip": ["clips", "Clip|Clips|m", "clip|clips|m", "clip|clips|m"],
	"handle": ["handles", "Griff|Griffe|m", "poignée|poignées|f", "asa|asas|f"],
	"cutout": ["cutouts", "Aussparung|Aussparungen|f", "découpe|découpes|f", "recorte|recortes|m"],
	"slot": ["slots", "Schlitz|Schlitze|m", "fente|fentes|f", "ranura|ranuras|f"],
	"side": ["sides", "Seite|Seiten|f", "côté|côtés|m", "lado|lados|m"],
	"end": ["ends", "Ende|Enden|n", "extrémité|extrémités|f", "extremo|extremos|m"],
	"corner": ["corners", "Ecke|Ecken|f", "coin|coins|m", "esquina|esquinas|f"],
	"edge": ["edges", "Kante|Kanten|f", "bord|bords|m", "borde|bordes|m"],
	"notch": ["notches", "Kerbe|Kerben|f", "encoche|encoches|f", "muesca|muescas|f"],
	"peghole": ["pegholes", "Pinloch|Pinlöcher|n", "trou de cheville|trous de cheville|m", "agujero de pasador|agujeros de pasador|m"],
	"pinhole": ["pinholes", "Pinloch|Pinlöcher|n", "trou de cheville|trous de cheville|m", "agujero de pasador|agujeros de pasador|m"],
	"tooth": ["teeth", "Zahn|Zähne|m", "dent|dents|f", "diente|dientes|m"],
	"spoke": ["spokes", "Speiche|Speichen|f", "rayon|rayons|m", "radio|radios|m"],
	"pane": ["panes", "Scheibe|Scheiben|f", "vitre|vitres|f", "cristal|cristales|m"],
	"rib": ["ribs", "Rippe|Rippen|f", "nervure|nervures|f", "nervio|nervios|m"],
	"ridge": ["ridges", "Grat|Grate|m", "arête|arêtes|f", "cresta|crestas|f"],
	"towball": ["towballs", "Kugelkopf|Kugelköpfe|m", "rotule|rotules|f", "rótula|rótulas|f"],
	"socket": ["sockets", "Pfanne|Pfannen|f", "douille|douilles|f", "cavidad|cavidades|f"],
	"ball": ["balls", "Kugel|Kugeln|f", "boule|boules|f", "bola|bolas|f"],
	"hook": ["hooks", "Haken|Haken|m", "crochet|crochets|m", "gancho|ganchos|m"],
	"knob": ["knobs", "Knauf|Knäufe|m", "bouton|boutons|m", "pomo|pomos|m"],
	"stop": ["stops", "Anschlag|Anschläge|m", "butée|butées|f", "tope|topes|m"],
	"sill": ["sills", "Sims|Simse|m", "rebord|rebords|m", "alféizar|alféizares|m"],
	"frame": ["frames", "Rahmen|Rahmen|m", "cadre|cadres|m", "marco|marcos|m"],
	"window": ["windows", "Fenster|Fenster|n", "fenêtre|fenêtres|f", "ventana|ventanas|f"],
	"door": ["doors", "Tür|Türen|f", "porte|portes|f", "puerta|puertas|f"],
	"glass": ["glasses", "Glas|Gläser|n", "vitre|vitres|f", "cristal|cristales|m"],
	"base": ["bases", "Sockel|Sockel|m", "base|bases|f", "base|bases|f"],
	"lid": ["lids", "Deckel|Deckel|m", "couvercle|couvercles|m", "tapa|tapas|f"],
	"underside": ["undersides", "Unterseite|Unterseiten|f", "dessous|dessous|m", "parte inferior|partes inferiores|f"],
	"top": ["tops", "Oberseite|Oberseiten|f", "dessus|dessus|m", "parte superior|partes superiores|f"],
	"bottom": ["bottoms", "Unterseite|Unterseiten|f", "dessous|dessous|m", "parte inferior|partes inferiores|f"],
	"centre": ["centres", "Mitte|Mitten|f", "centre|centres|m", "centro|centros|m"],
	"center": ["centers", "Mitte|Mitten|f", "centre|centres|m", "centro|centros|m"],
	"point": ["points", "Spitze|Spitzen|f", "pointe|pointes|f", "punta|puntas|f"],
	"tip": ["tips", "Spitze|Spitzen|f", "embout|embouts|m", "punta|puntas|f"],
	"bar": ["bars", "Stange|Stangen|f", "barre|barres|f", "barra|barras|f"],
	"plate": ["plates", "Platte|Platten|f", "plaque|plaques|f", "placa|placas|f"],
	"brick": ["bricks", "Stein|Steine|m", "brique|briques|f", "ladrillo|ladrillos|m"],
	"tile": ["tiles", "Fliese|Fliesen|f", "plaque lisse|plaques lisses|f", "baldosa|baldosas|f"],
	"hinge": ["hinges", "Scharnier|Scharniere|n", "charnière|charnières|f", "bisagra|bisagras|f"],
	"arm": ["arms", "Arm|Arme|m", "bras|bras|m", "brazo|brazos|m"],
	"finger": ["fingers", "Finger|Finger|m", "doigt|doigts|m", "dedo|dedos|m"],
	"tube": ["tubes", "Röhre|Röhren|f", "tube|tubes|m", "tubo|tubos|m"],
	"wheel": ["wheels", "Rad|Räder|n", "roue|roues|f", "rueda|ruedas|f"],
	"tyre": ["tyres", "Reifen|Reifen|m", "pneu|pneus|m", "neumático|neumáticos|m"],
	"rim": ["rims", "Felge|Felgen|f", "jante|jantes|f", "llanta|llantas|f"],
	"grille": ["grilles", "Gitter|Gitter|n", "grille|grilles|f", "rejilla|rejillas|f"],
	"headlight": ["headlights", "Scheinwerfer|Scheinwerfer|m", "phare|phares|m", "faro|faros|m"],
	"piston": ["pistons", "Kolben|Kolben|m", "piston|pistons|m", "pistón|pistones|m"],
	"spring": ["springs", "Feder|Federn|f", "ressort|ressorts|m", "muelle|muelles|m"],
	"chamfer": ["chamfers", "Fase|Fasen|f", "chanfrein|chanfreins|m", "chaflán|chaflanes|m"],
	"bevel": ["bevels", "Fase|Fasen|f", "biseau|biseaux|m", "bisel|biseles|m"],
	"lattice": ["lattices", "Gitter|Gitter|n", "treillis|treillis|m", "celosía|celosías|f"],
	"fin": ["fins", "Flosse|Flossen|f", "aileron|ailerons|m", "aleta|aletas|f"],
	"rail": ["rails", "Schiene|Schienen|f", "rail|rails|m", "riel|rieles|m"],
	"arch": ["arches", "Bogen|Bögen|m", "arche|arches|f", "arco|arcos|m"],
	"clutch": ["clutches", "Kupplung|Kupplungen|f", "embrayage|embrayages|m", "embrague|embragues|m"],
	"rack": ["racks", "Zahnstange|Zahnstangen|f", "crémaillère|crémaillères|f", "cremallera|cremalleras|f"],
	"ring": ["rings", "Ring|Ringe|m", "anneau|anneaux|m", "anillo|anillos|m"],
	"stub": ["stubs", "Stummel|Stummel|m", "tétine|tétines|f", "muñón|muñones|m"],
	"recess": ["recesses", "Vertiefung|Vertiefungen|f", "renfoncement|renfoncements|m", "hueco|huecos|m"],
	"shaft": ["shafts", "Schaft|Schäfte|m", "arbre|arbres|m", "eje|ejes|m"],
	"opening": ["openings", "Öffnung|Öffnungen|f", "ouverture|ouvertures|f", "abertura|aberturas|f"],
	"lip": ["lips", "Lippe|Lippen|f", "lèvre|lèvres|f", "labio|labios|m"],
	"mount": ["mounts", "Halterung|Halterungen|f", "support|supports|m", "soporte|soportes|m"],
	"holder": ["holders", "Halter|Halter|m", "support|supports|m", "soporte|soportes|m"],
	"tab": ["tabs", "Lasche|Laschen|f", "languette|languettes|f", "lengüeta|lengüetas|f"],
	"step": ["steps", "Stufe|Stufen|f", "marche|marches|f", "escalón|escalones|m"],
	"wall": ["walls", "Wand|Wände|f", "mur|murs|m", "pared|paredes|f"],
	"tread": ["treads", "Profil|Profile|n", "bande de roulement|bandes de roulement|f", "banda de rodadura|bandas de rodadura|f"],
	"sidewall": ["sidewalls", "Flanke|Flanken|f", "flanc|flancs|m", "flanco|flancos|m"],
	"understud": ["understuds", "Unternoppe|Unternoppen|f", "tenon inférieur|tenons inférieurs|m", "espiga inferior|espigas inferiores|f"],
	"reinforcement": ["reinforcements", "Verstärkung|Verstärkungen|f", "renfort|renforts|m", "refuerzo|refuerzos|m"],
	"stopper ring": ["stopper rings", "Anschlagring|Anschlagringe|m", "anneau de butée|anneaux de butée|m", "anillo de tope|anillos de tope|m"],
	"friction": ["frictions", "Reibung|Reibungen|f", "friction|frictions|f", "fricción|fricciones|f"],
	"flange": ["flanges", "Flansch|Flansche|m", "collerette|collerettes|f", "brida|bridas|f"],
	"door rail": ["door rails", "Türschiene|Türschienen|f", "rail de porte|rails de porte|m", "riel de puerta|rieles de puerta|m"],
	"pin hole": ["pin holes", "Pinloch|Pinlöcher|n", "trou de cheville|trous de cheville|m", "agujero de pasador|agujeros de pasador|m"],
	"axle hole": ["axle holes", "Achsloch|Achslöcher|n", "trou d'essieu|trous d'essieu|m", "agujero de eje|agujeros de eje|m"],
	"bar hole": ["bar holes", "Stangenloch|Stangenlöcher|n", "trou de barre|trous de barre|m", "agujero de barra|agujeros de barra|m"],
	"stud holder": ["stud holders", "Noppenhalter|Noppenhalter|m", "support de tenon|supports de tenon|m", "soporte de espiga|soportes de espiga|m"],
	"wheel pin": ["wheel pins", "Radpin|Radpins|m", "cheville de roue|chevilles de roue|f", "pasador de rueda|pasadores de rueda|m"],
}

## What comes before a noun: German's word with the case it takes after it.
const PREPOSITIONS: Dictionary = {
	"with": ["mit|dat", "avec", "con"],
	"without": ["ohne|acc", "sans", "sin"],
	"on": ["an|dat", "sur", "en"],
	"for": ["für|acc", "pour", "para"],
	"in": ["in|dat", "dans", "en"],
	"between": ["zwischen|dat", "entre", "entre"],
}
const AND: Array[String] = ["und", "et", "y"]
## A count in words; one and both by the noun's gender and German's case.
const NUMBERS: Dictionary = {"two": ["zwei", "deux", "dos"], "three": ["drei", "trois", "tres"],
	"four": ["vier", "quatre", "cuatro"]}
const ONE: Dictionary = {
	"nom": {"m": "ein", "f": "eine", "n": "ein"}, "dat": {"m": "einem", "f": "einer", "n": "einem"},
	"acc": {"m": "einen", "f": "eine", "n": "ein"}}
## A product line's name, kept: before the kind in German, after it in
## French and Spanish (Technic Stein, Brique Technic).
const BRANDS: Dictionary = {"technic": "Technic", "duplo": "Duplo", "modulex": "Modulex",
	"primo": "Primo", "quatro": "Quatro", "fabuland": "Fabuland", "znap": "Znap"}
## German's endings for an adjective before a noun with no article, by case.
const DE_ENDINGS: Dictionary = {
	"nom": {"m": "er", "n": "es", "f": "e", "pl": "e"},
	"dat": {"m": "em", "n": "em", "f": "er", "pl": "en"},
	"acc": {"m": "en", "n": "es", "f": "e", "pl": "e"},
}
const VOWELS: Array[String] = ["a", "e", "i", "o", "u", "á", "é", "í", "ó", "ú"]

## A colour's words, as LDraw names it: what it is made of first (Trans,
## Pearl), then its shade (Light), a tint (Bluish) and its hue (Grey).
## German makes one word of shade, tint and hue (Hellblaugrau), with what it
## is made of before it (Transparent-Rot); French and Spanish put the hue
## first and the rest after it, nearest first (Gris bleuté clair, Rojo
## transparente). "" where a language has no word for it.
const HUES: Dictionary = {
	"black": ["schwarz", "Noir", "Negro"], "white": ["weiß", "Blanc", "Blanco"],
	"red": ["rot", "Rouge", "Rojo"], "blue": ["blau", "Bleu", "Azul"],
	"yellow": ["gelb", "Jaune", "Amarillo"], "green": ["grün", "Vert", "Verde"],
	"grey": ["grau", "Gris", "Gris"], "gray": ["grau", "Gris", "Gris"],
	"brown": ["braun", "Brun", "Marrón"], "orange": ["orange", "Orange", "Naranja"],
	"pink": ["rosa", "Rose", "Rosa"], "purple": ["lila", "Pourpre", "Morado"],
	"violet": ["violett", "Violet", "Violeta"], "tan": ["beige", "Beige", "Beige"],
	"lime": ["limette", "Citron vert", "Lima"], "gold": ["gold", "Or", "Oro"],
	"silver": ["silber", "Argent", "Plata"], "copper": ["kupfer", "Cuivre", "Cobre"],
	"azure": ["azurblau", "Azur", "Azur"], "aqua": ["aqua", "Aigue-marine", "Aguamarina"],
	"lavender": ["lavendel", "Lavande", "Lavanda"], "lilac": ["flieder", "Lilas", "Lila"],
	"magenta": ["magenta", "Magenta", "Magenta"], "turquoise": ["türkis", "Turquoise", "Turquesa"],
	"coral": ["koralle", "Corail", "Coral"], "salmon": ["lachs", "Saumon", "Salmón"],
	"nougat": ["nougat", "Nougat", "Nougat"], "cyan": ["cyan", "Cyan", "Cian"],
}
const SHADES: Dictionary = {
	"light": ["hell", "clair", "claro"], "dark": ["dunkel", "foncé", "oscuro"],
	"medium": ["mittel", "moyen", "medio"], "bright": ["leuchtend", "vif", "brillante"],
	"very light": ["", "très clair", "muy claro"], "very dark": ["", "très foncé", "muy oscuro"],
}
const TINTS: Dictionary = {
	"bluish": ["blau", "bleuté", "azulado"], "reddish": ["rot", "rougeâtre", "rojizo"],
	"yellowish": ["gelb", "jaunâtre", "amarillento"], "sand": ["sand", "sable", "arena"],
	"olive": ["oliv", "olive", "oliva"], "sky": ["himmel", "ciel", "cielo"],
}
const MADE_OF: Dictionary = {
	"trans": ["Transparent", "transparent", "transparente"], "pearl": ["Perl", "nacré", "perlado"],
	"metallic": ["Metallic", "métallisé", "metalizado"], "chrome": ["Chrom", "chromé", "cromado"],
	"glitter": ["Glitzer", "pailleté", "con purpurina"], "rubber": ["Gummi", "caoutchouc", "de goma"],
	"satin": ["Satin", "satiné", "satinado"], "opal": ["Opal", "opalescent", "opalino"],
}

## Each language's words that say nothing of which part, for a search.
const SAYS_NOTHING: Array = [
	["der", "die", "das", "den", "dem", "des", "ein", "eine", "einen", "einem", "einer"],
	["le", "la", "les", "l", "un", "une", "des", "du", "de", "d", "a", "au", "aux"],
	["el", "la", "los", "las", "un", "una", "unos", "unas", "de", "del", "al", "e"],
]
## A letter as a search reads it, its accent taken off.
const PLAIN: Dictionary = {"à": "a", "â": "a", "ä": "a", "á": "a", "ç": "c", "é": "e", "è": "e",
	"ê": "e", "ë": "e", "í": "i", "î": "i", "ï": "i", "ñ": "n", "ó": "o", "ô": "o", "ö": "o",
	"ú": "u", "ù": "u", "û": "u", "ü": "u", "ß": "ss", "œ": "oe"}

## A size or a count as LDraw writes it: 2, 1×2, 1 x 2 x 0.667, 1/2, 4L, 12V, #3.
static var NUMBER := RegEx.create_from_string(
	"^(#?\\d+(\\.\\d+)?(/\\d+)?|\\.\\d+)( ?[x×] ?(\\d+(\\.\\d+)?(/\\d+)?|\\.\\d+))*(L|V|mm)?$")
## The nouns by their English, singular and plural: -> [entry, whether plural].
## Made as the class loads, as a list row's name is said on any thread.
static var _nouns: Dictionary = _nouns_by_word()
## The adjectives' and nouns' English of more than one word ("pin hole").
static var _phrases: Dictionary = _phrases_of()
## Each language's words read back for a search, made the first time asked.
static var _spoken: Dictionary = {}
static var _spoken_lock := Mutex.new()


## [param text] in [param code]'s language, a part's name or a colour's;
## "" where the glossary cannot say it whole, or in English.
static func said(text: String, code: String) -> String:
	var named: String = part(text, code)
	return named if not named.is_empty() else colour(text, code)


## A part's name, as LDraw writes it or the bin shows it ("Brick 1×2",
## "Plate 1 x 2 with Door Rail"), in [param code]'s language, or "".
static func part(name: String, code: String) -> String:
	var lang: int = int(LANGUAGES.get(code, -1))
	if lang < 0:
		return ""
	var written: PackedStringArray = _words_of(name)
	var at: int = 0
	var brands := PackedStringArray()
	while at < written.size() and BRANDS.has(written[at].to_lower()):
		brands.append(BRANDS[written[at].to_lower()])
		at += 1
	var kind: Array = []
	for n: int in [3, 2, 1]:
		var key: String = " ".join(written.slice(at, at + n)).to_lower()
		if at + n <= written.size() and KINDS.has(key):
			kind = KINDS[key]
			at += n
			break
	if kind.is_empty():
		return ""
	var head: PackedStringArray = str(kind[lang]).split("|")
	var gender: String = head[1] if head.size() > 1 else "m"
	var out := PackedStringArray()
	if lang == 0:
		out.append_array(brands)
	out.append(head[0])
	if lang > 0:
		out.append_array(brands)
	var words: PackedStringArray = _joined_phrases(written.slice(at))
	var low := PackedStringArray()
	for word: String in words:
		low.append(word.to_lower())
	at = 0
	while at < words.size():
		var word: String = words[at]
		if _is_number(word):
			# A count of something: "Gear 24 Tooth".
			if at + 1 < words.size() and _nouns.has(low[at + 1]) and not ADJECTIVES.has(low[at + 1]):
				var counted: Array = _group(words, low, at, lang, "nom")
				if counted.is_empty():
					return ""
				out.append(counted[0])
				at = counted[1]
				continue
			out.append(word)
			at += 1
			continue
		if word == "-" or word == "/":
			out.append(word)
			at += 1
			continue
		if word == ",":
			out[out.size() - 1] = out[out.size() - 1] + ","
			at += 1
			continue
		if low[at] == "and" and at + 1 < words.size() and PREPOSITIONS.has(low[at + 1]):
			out.append(AND[lang])
			at += 1
		if PREPOSITIONS.has(low[at]):
			var before: PackedStringArray = str(PREPOSITIONS[low[at]][lang]).split("|")
			var case: String = before[1] if before.size() > 1 else ""
			var group: Array = _group(words, low, at + 1, lang, case)
			if group.is_empty():
				return ""
			out.append(before[0])
			out.append(group[0])
			at = group[1]
			# "with Groove and Hole": the next noun after the same word.
			while at + 1 < words.size() and low[at] == "and" and not PREPOSITIONS.has(low[at + 1]):
				var more: Array = _group(words, low, at + 1, lang, case)
				if more.is_empty():
					return ""
				out.append(_and(lang, str(more[0])))
				out.append(more[0])
				at = more[1]
			continue
		if ADJECTIVES.has(low[at]):
			out.append(_adjective(low[at], lang, gender, false, "", false))
			at += 1
			continue
		if BRANDS.has(low[at]):
			out.append(BRANDS[low[at]])
			at += 1
			continue
		return ""
	var text: String = " ".join(out)
	return text.left(1).to_upper() + text.substr(1)


## A colour's name ("Light Bluish Grey", "Trans Red") in [param code]'s
## language, or "".
static func colour(name: String, code: String) -> String:
	var lang: int = int(LANGUAGES.get(code, -1))
	if lang < 0:
		return ""
	var words: PackedStringArray = name.to_lower().split(" ", false)
	var at: int = 0
	var made := PackedStringArray()
	while at < words.size() and MADE_OF.has(words[at]):
		made.append(words[at])
		at += 1
	var shade: String = ""
	for n: int in [2, 1]:
		if at + n <= words.size() and SHADES.has(" ".join(words.slice(at, at + n))):
			shade = " ".join(words.slice(at, at + n))
			at += n
			break
	var tint: String = ""
	if at + 1 < words.size() and TINTS.has(words[at]):
		tint = words[at]
		at += 1
	if at != words.size() - 1:
		return ""
	var hue: String = words[at]
	var said := PackedStringArray()
	if hue == "clear":
		# Trans Clear is clear plastic: transparent, said alone.
		if not made.has("trans") or not shade.is_empty() or not tint.is_empty():
			return ""
		made.erase("trans")
		said.append(str(MADE_OF["trans"][lang]).capitalize() if lang > 0 else MADE_OF["trans"][0])
	elif not HUES.has(hue):
		return ""
	elif lang == 0:
		var german: String = (str(SHADES[shade][0]) if not shade.is_empty() else "") \
			+ (str(TINTS[tint][0]) if not tint.is_empty() else "") + str(HUES[hue][0])
		if not shade.is_empty() and str(SHADES[shade][0]).is_empty():
			return ""
		said.append(german.left(1).to_upper() + german.substr(1))
	else:
		said.append(HUES[hue][lang])
		if not tint.is_empty():
			said.append(TINTS[tint][lang])
		if not shade.is_empty():
			said.append(SHADES[shade][lang])
	if lang == 0:
		var prefix: String = ""
		for word: String in made:
			prefix += str(MADE_OF[word][0]) + "-"
		return prefix + said[0]
	for n: int in range(made.size() - 1, -1, -1):
		said.append(MADE_OF[made[n]][lang])
	return " ".join(said)


## The words of [param name], a size written apart ("1 x 2 x 0.667") as
## one and a comma after a word as one of its own.
static func _words_of(name: String) -> PackedStringArray:
	var raw: PackedStringArray = name.split(" ", false)
	var out := PackedStringArray()
	var at: int = 0
	while at < raw.size():
		var word: String = raw[at]
		var last: int = out.size() - 1
		if (word == "x" or word == "×") and last >= 0 and at + 1 < raw.size() \
				and _is_number(out[last]) and _is_number(raw[at + 1].trim_suffix(",")):
			out[last] = "%s %s %s" % [out[last], word, raw[at + 1].trim_suffix(",")]
			if raw[at + 1].ends_with(",") and raw[at + 1].length() > 1:
				out.append(",")
			at += 2
			continue
		if word.ends_with(",") and word.length() > 1:
			out.append(word.left(-1))
			out.append(",")
		else:
			out.append(word)
		at += 1
	return out


## [param words] with the phrases of the glossary ("Pin Hole") each one.
static func _joined_phrases(words: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var at: int = 0
	while at < words.size():
		var joined: int = 1
		for n: int in [3, 2]:
			if at + n <= words.size() and _phrases.has(" ".join(words.slice(at, at + n)).to_lower()):
				joined = n
				break
		out.append(" ".join(words.slice(at, at + joined)))
		at += joined
	return out


static func _is_number(word: String) -> bool:
	return NUMBER.search(word) != null


## What follows a preposition, or a count: [a count] [adjectives] a noun
## [adjectives], said in [param lang] in [param case] (German's), as
## [its words, the index after it]; or [] where it cannot be.
static func _group(words: PackedStringArray, low: PackedStringArray, at: int, lang: int,
		case: String) -> Array:
	var count: String = ""
	if at < low.size() and (_is_number(words[at]) or NUMBERS.has(low[at])
			or low[at] in ["one", "both"]):
		count = low[at]
		at += 1
	var run: Array[int] = []
	var end: int = at
	while end < low.size() and (ADJECTIVES.has(low[end]) or _nouns.has(low[end])
			or BRANDS.has(low[end])):
		run.append(end)
		end += 1
	# The noun: the last of the run with nothing but adjectives before it,
	# "with Curved Top", "without Bottom Tube".
	var head: int = -1
	for k: int in range(run.size() - 1, -1, -1):
		if not _nouns.has(low[run[k]]):
			continue
		var plain: bool = true
		for x: int in run.slice(0, k):
			plain = plain and (ADJECTIVES.has(low[x]) or BRANDS.has(low[x]))
		if plain:
			head = k
			break
	if head < 0:
		return []
	var noun: Array = _nouns[low[run[head]]]
	var plural: bool = bool(noun[1]) or not count in ["", "1", "one"]
	var forms: PackedStringArray = str((noun[0] as Array)[lang + 1]).split("|")
	var gender: String = forms[2]
	var word: String = forms[1] if plural else forms[0]
	if lang == 0 and plural and case == "dat" and not word.right(1) in ["n", "s"]:
		word += "n"
	# And the adjectives after it, which are its: "with Clip Vertical".
	var after: Array[int] = []
	for x: int in run.slice(head + 1):
		if not ADJECTIVES.has(low[x]):
			break
		after.append(x)
	var brands := PackedStringArray()
	var adjectives := PackedStringArray()
	for x: int in run.slice(0, head) + after:
		if BRANDS.has(low[x]):
			brands.append(BRANDS[low[x]])
			continue
		var adjective: String = _adjective(low[x], lang, gender, plural, case, true)
		if adjective.is_empty():
			return []
		adjectives.append(adjective)
	var pieces := PackedStringArray()
	if count == "one":
		pieces.append(ONE[case if ONE.has(case) else "nom"][gender] if lang == 0
			else ("une" if gender == "f" else "un") if lang == 1 else ("una" if gender == "f" else "un"))
	elif count == "both":
		pieces.append(("beiden" if case == "dat" else "beide") if lang == 0 else "les deux" if lang == 1
			else ("ambas" if gender == "f" else "ambos"))
	elif NUMBERS.has(count):
		pieces.append(NUMBERS[count][lang])
	elif not count.is_empty():
		pieces.append(words[at - 1])
	if lang == 0:
		pieces.append_array(adjectives)
		pieces.append_array(brands)
		pieces.append(word)
	else:
		pieces.append(word)
		pieces.append_array(brands)
		pieces.append_array(adjectives)
	return [" ".join(pieces), (after[after.size() - 1] if not after.is_empty() else run[head]) + 1]


## [param key]'s adjective in [param lang], agreeing with a noun of
## [param gender] and [param plural]; in German declined in [param case]
## where it stands [param before] the noun, as it is after one otherwise.
## "" where it cannot stand there.
static func _adjective(key: String, lang: int, gender: String, plural: bool, case: String,
		before: bool) -> String:
	var spec: PackedStringArray = str(ADJECTIVES[key][lang]).split("/")
	if lang == 0:
		if not before:
			return spec[0]
		var stem: String = spec[1] if spec.size() > 1 else spec[0]
		if stem.is_empty():
			return ""
		var ending: String = DE_ENDINGS[case if DE_ENDINGS.has(case) else "nom"]["pl" if plural else gender]
		return stem + (ending.substr(1) if stem.ends_with("e") else ending)
	var forms: PackedStringArray = spec
	if forms.size() != 4:
		var m: String = spec[0]
		if lang == 1:
			var f: String = m if m.ends_with("e") else m + "e"
			forms = PackedStringArray([m, f, m if m.right(1) in ["s", "x"] else m + "s", f + "s"])
		elif m.ends_with("o"):
			var a: String = m.left(-1) + "a"
			forms = PackedStringArray([m, a, m + "s", a + "s"])
		else:
			var many: String = m + ("s" if m.right(1) in VOWELS else "es")
			forms = PackedStringArray([m, m, many, many])
	return forms[(1 if gender == "f" else 0) + (2 if plural else 0)]


## Spanish's "and" is "e" before a word that begins with an i.
static func _and(lang: int, next: String) -> String:
	var low: String = next.to_lower()
	if lang == 2 and (low.begins_with("i") or low.begins_with("hi")) \
			and not low.begins_with("hie") and not low.begins_with("hia"):
		return "e"
	return AND[lang]


static func _nouns_by_word() -> Dictionary:
	var out: Dictionary = {}
	for english: String in NOUNS:
		out[english] = [NOUNS[english], false]
		out[NOUNS[english][0]] = [NOUNS[english], true]
	return out


static func _phrases_of() -> Dictionary:
	var out: Dictionary = {}
	for english: String in _nouns.keys() + ADJECTIVES.keys():
		if " " in english:
			out[english] = true
	return out


## [param text] lowered and its accents taken off, as a search compares it.
static func plain(text: String) -> String:
	var out: String = ""
	for letter: String in text.to_lower():
		out += str(PLAIN.get(letter, letter))
	return out


## [param code]'s words read back, for a search: each word or phrase, in
## each of its forms, lowered and without its accents, -> LDraw's words for
## it, or none for one that says nothing of which part (avec, mit).
static func spoken(code: String) -> Dictionary:
	var lang: int = int(LANGUAGES.get(code, -1))
	if lang < 0:
		return {}
	_spoken_lock.lock()
	var known: Variant = _spoken.get(code)
	if known == null:
		known = _read_back(lang)
		_spoken[code] = known
	_spoken_lock.unlock()
	return known


static func _read_back(lang: int) -> Dictionary:
	var out: Dictionary = {}
	for english: String in KINDS:
		_hear(out, str(KINDS[english][lang]).get_slice("|", 0), english)
	for english: String in NOUNS:
		var forms: PackedStringArray = str(NOUNS[english][lang + 1]).split("|")
		_hear(out, forms[0], english)
		_hear(out, forms[1], NOUNS[english][0])
		if lang == 0:
			_hear(out, forms[1] + "n", NOUNS[english][0])
	for english: String in ADJECTIVES:
		var spec: PackedStringArray = str(ADJECTIVES[english][lang]).split("/")
		if lang == 0:
			_hear(out, spec[0], english)
			var stem: String = spec[1] if spec.size() > 1 else spec[0]
			for ending: String in ["e", "er", "en", "em", "es"]:
				if not stem.is_empty():
					_hear(out, stem + ending, english)
			continue
		for gender: String in ["m", "f"]:
			for plural: bool in [false, true]:
				_hear(out, _adjective(english, lang, gender, plural, "", false), english)
	for english: String in PREPOSITIONS:
		_hear(out, str(PREPOSITIONS[english][lang]).get_slice("|", 0),
			"" if PartSearch.STOP_WORDS.has(english) else english)
	for english: String in NUMBERS:
		_hear(out, NUMBERS[english][lang], english)
	for table: Dictionary in [HUES, SHADES, TINTS, MADE_OF]:
		for english: String in table:
			_hear(out, table[english][lang], english)
	for word: String in SAYS_NOTHING[lang] + [AND[lang]]:
		_hear(out, word, "")
	return out


static func _hear(out: Dictionary, said: String, english: String) -> void:
	var key: String = " ".join(PartSearch.words_of(plain(said)))
	if key.is_empty() or key == english:
		return
	var heard: PackedStringArray = out.get(key, PackedStringArray())
	if not english.is_empty() and not heard.has(english):
		heard.append(english)
	out[key] = heard


## The spans of [param words] (a query's, PartSearch.words_of) that
## [param spoken] has, the longest first: [the first word, how many, LDraw's
## words for them], none for words that say nothing.
static func heard(words: PackedStringArray, spoken: Dictionary) -> Array:
	var out: Array = []
	var at: int = 0
	while at < words.size():
		var found: int = 0
		for n: int in range(mini(4, words.size() - at), 0, -1):
			var key: String = plain(" ".join(words.slice(at, at + n)))
			if spoken.has(key):
				out.append([at, n, spoken[key]])
				found = n
				break
		at += maxi(found, 1)
	return out


## The words [param spoken] has that begin with [param typed], a word on its
## way to one (brique), -> LDraw's for them; at most [param most].
static func begun(typed: String, spoken: Dictionary, most: int = 8) -> PackedStringArray:
	var out := PackedStringArray()
	var start: String = plain(typed)
	if start.length() < 3:
		return out
	for key: String in spoken:
		if key.begins_with(start) and key != start and not " " in key:
			for english: String in spoken[key]:
				if not out.has(english):
					out.append(english)
			if out.size() >= most:
				break
	return out
