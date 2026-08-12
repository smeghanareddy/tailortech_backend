# Design library + demo accounts.
#
# Element names deliberately match the icon maps in the React app
# (NECK_ICONS / SLEEVE_ICONS / DRESS_ICONS in DesignStudioPage.jsx) so the
# option grid renders an icon for every seeded item until real transparent
# PNGs are uploaded through the Super Admin library.
#
# Idempotent: safe to re-run.

puts "→ Seeding TailorTech…"

# ── Users ────────────────────────────────────────────────────────
admin = User.find_or_initialize_by(email: "admin@tailortech.app")
admin.assign_attributes(name: "Super Admin", role: :super_admin, password: "password123")
admin.save!

designers = [
  { email: "priya@tailortech.app", name: "Priya Ramesh", city: "Chennai", state: "Tamil Nadu",
    bio: "Bridal lehengas and hand-embroidered blouses. 12 years at the machine.",
    rating: 4.8, reviews_count: 126, years_experience: 12, specialization: "Bridal",
    latitude: 13.0827, longitude: 80.2707 },
  { email: "aisha@tailortech.app", name: "Aisha Khan", city: "Hyderabad", state: "Telangana",
    bio: "Anarkalis, shararas and contemporary fusion wear.",
    rating: 4.6, reviews_count: 84, years_experience: 8, specialization: "Ethnic Fusion",
    latitude: 17.3850, longitude: 78.4867 },
  { email: "meera@tailortech.app", name: "Meera Nair", city: "Kochi", state: "Kerala",
    bio: "Kerala kasavu, minimal silhouettes, precise fits.",
    rating: 4.9, reviews_count: 201, years_experience: 15, specialization: "Traditional",
    latitude: 9.9312, longitude: 76.2673 }
].map do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.assign_attributes(attrs.merge(role: :designer, password: "password123"))
  user.save!
  user
end

customer = User.find_or_initialize_by(email: "customer@tailortech.app")
customer.assign_attributes(name: "Divya Sharma", role: :customer, password: "password123",
                           city: "Chennai", state: "Tamil Nadu", phone: "+91 98400 11111")
customer.save!

DesignerCustomer.find_or_create_by!(designer: designers.first, customer: customer) do |link|
  link.created_by_designer = false
  link.notes = "Prefers cotton, sensitive to synthetic linings."
end

puts "  users: #{User.count}"

# ── Design library ───────────────────────────────────────────────

def upsert_element!(category, name, admin, **overrides)
  element = DesignElement.find_or_initialize_by(category: category, slug: name.parameterize)
  element.assign_attributes(
    {
      name: name,
      published: true,
      processing_status: "ready",
      created_by: admin
    }.merge(overrides)
  )
  element.save!
  element
end

# [name, one-line description, [bullet characteristics]]
#
# The bullets drive the Design Studio's detail view. They live here rather
# than in the frontend so a Super Admin can edit them through the Design
# Library without a deploy.
NECKLINES = [
  ["Round Neck", "A clean circular opening sitting at the collarbone.",
   ["Simple circular opening at the collarbone.",
    "Suits nearly every body type and face shape.",
    "The everyday default for kurtis, tops and tees."]],
  ["U-Neck", "Deeper than round, with a soft flat-bottomed U.",
   ["Deeper than a round neck, with a flat-bottomed curve.",
    "Elongates the neck without being revealing.",
    "Works well on blouses and A-line dresses."]],
  ["V-Neck", "Tapered V that lengthens the neckline.",
   ["Tapers to a point below the collarbone.",
    "Visually lengthens the neck and torso.",
    "Flattering on round and fuller face shapes."]],
  ["Deep V-Neck", "The V dropped well below the bust line.",
   ["The V continues well below the bust line.",
    "Bold and dramatic; a statement neckline.",
    "Usually needs an inner layer or modesty panel."]],
  ["Scoop Neck", "Wide and deep, scooped across the collarbones.",
   ["Wide, deep curve scooped across the collarbones.",
    "Relaxed and casual in feel.",
    "Pairs well with layered necklaces."]],
  ["Boat Neck", "Wide and shallow, running shoulder to shoulder.",
   ["Wide neckline extending toward the shoulders.",
    "Broadens the shoulder line and balances wide hips.",
    "Sophisticated; classic on fitted sheath dresses."]],
  ["Square Neck", "Straight horizontal line with squared corners.",
   ["Straight horizontal edge with squared corners.",
    "Frames the collarbone and softens a long neck.",
    "Popular on blouses and vintage-cut dresses."]],
  ["Sweetheart Neck", "Curved heart-shaped bodice edge.",
   ["Heart-shaped neckline curved over the bust.",
    "Feminine and elegant.",
    "Common in bridal gowns and party wear."]],
  ["Keyhole Neck", "Closed collar with a teardrop opening beneath.",
   ["Closed collar with a teardrop opening below it.",
    "Adds detail without lowering the neckline.",
    "Usually finished with a button and loop."]],
  ["Halter Neck", "Straps behind the neck; shoulders and back left open.",
   ["Straps fasten or tie behind the neck.",
    "Leaves the shoulders and upper back bare.",
    "Needs a matching backless or strapless bra."]],
  ["Off-Shoulder", "Neckline sits below both shoulders.",
   ["Neckline sits below both shoulders.",
    "Shows the collarbone and full shoulder line.",
    "Best in structured fabrics that hold their shape."]],
  ["High Neck", "Closed neckline rising to the base of the throat.",
   ["Closed neckline rising to the base of the throat.",
    "Modest and formal.",
    "Usually paired with a keyhole or buttoned back for fit."]],
  ["Collar Neck", "Shirt-style folded collar with a placket.",
   ["Shirt-style folded collar above a front placket.",
    "Crisp and tailored.",
    "Standard on shirts, shirt-dresses and tunics."]]
].freeze

BACK_NECKLINES = [
  ["High Back", "Closed back matching a high front neckline.",
   ["Closed back rising to the nape.",
    "The safe partner for a high front neckline.",
    "Needs a zip or button placket to get over the head."]],
  ["Keyhole", "Small teardrop opening below the collar.",
   ["Small teardrop opening below a closed collar.",
    "Adds interest to an otherwise plain back.",
    "Fastens with a single button and loop."]],
  ["Deep U", "Deep scooped back.",
   ["Deeply scooped back curve.",
    "Dramatic; the back becomes the feature.",
    "Not compatible with a high front neckline."]],
  ["Deep V", "Deep V-shaped back.",
   ["Back tapers to a deep V point.",
    "Lengthens the line of the back.",
    "Needs careful fitting to stay in place."]],
  ["Round Back", "Plain rounded back neckline.",
   ["Plain rounded back opening.",
    "Comfortable and unobtrusive.",
    "Works with every front neckline."]]
].freeze

# The full list from the spec. Length-based styles first, then shape-based.
SLEEVES = [
  ["Sleeveless", "No sleeve; clean armhole finish.",
   ["No sleeve — the armhole is simply bound or faced.",
    "Coolest option; shows the full shoulder and arm.",
    "Common on summer kurtis and party blouses."]],
  ["Cap Sleeve", "Short cap covering just the shoulder cap.",
   ["Very short, covering only the top of the shoulder.",
    "Softens the shoulder line without adding warmth.",
    "A modest alternative to sleeveless."]],
  ["Short Sleeve", "Straight sleeve ending above the elbow.",
   ["Straight sleeve finishing above the elbow.",
    "The most common everyday length.",
    "Easy to wear in any fabric."]],
  ["Elbow Sleeve", "Ends level with the elbow.",
   ["Finishes level with the elbow.",
    "More coverage than short without restricting movement.",
    "Popular on office and daily wear."]],
  ["3/4 Sleeve", "Ends between elbow and wrist.",
   ["Ends midway between elbow and wrist.",
    "Flattering — it narrows at the slimmest part of the forearm.",
    "Leaves bangles and watches on show."]],
  ["Full Sleeve", "Runs the length of the arm to the wrist.",
   ["Runs the full length of the arm to the wrist.",
    "Maximum coverage; warmest option.",
    "Standard for formal and winter wear."]],
  ["Puff Sleeve", "Gathered volume at the shoulder, fitted below.",
   ["Gathered volume concentrated at the shoulder.",
    "Broadens the shoulder and balances wider hips.",
    "Needs a fabric with body to hold the puff."]],
  ["Bell Sleeve", "Narrow at the shoulder, flaring wide at the opening.",
   ["Narrow at the shoulder, flaring wide at the opening.",
    "Dramatic movement; draws the eye downward.",
    "Best in fabrics that drape, like georgette or chiffon."]],
  ["Bishop Sleeve", "Full through the arm, gathered into a fitted cuff.",
   ["Full and blousy through the arm.",
    "Gathered into a fitted cuff at the wrist.",
    "Romantic; a staple of ethnic and boho styles."]],
  ["Balloon Sleeve", "Rounded volume through the whole sleeve.",
   ["Rounded volume through the entire sleeve.",
    "Bolder than a puff — the whole arm is full.",
    "Statement piece; keep the rest of the dress simple."]],
  ["Flutter Sleeve", "Short layered ruffle falling loose over the arm.",
   ["Short, loose ruffle falling over the upper arm.",
    "Ungathered — it flutters instead of puffing.",
    "Light and feminine; ideal for summer dresses."]],
  ["Raglan Sleeve", "Diagonal seam running from underarm to collar.",
   ["Diagonal seam runs from underarm up to the collar.",
    "No shoulder seam, so movement is unrestricted.",
    "Casual and sporty in feel."]],
  ["Kimono Sleeve", "Cut in one piece with the bodice; wide and straight.",
   ["Cut in one piece with the bodice — no armhole seam.",
    "Wide, straight and loose.",
    "Relaxed drape; forgiving over the upper arm."]],
  ["Cold Shoulder", "Fitted sleeve with the shoulder left open.",
   ["A fitted sleeve with the shoulder cut away.",
    "Combines coverage with a bare shoulder.",
    "Needs a strap or yoke to hold the sleeve up."]]
].freeze

DRESS_TYPES = [
  ["Straight Cut", "Column silhouette, no flare."],
  ["A-Line",       "Fitted at the bodice, widening to the hem."],
  ["Anarkali",     "Fitted bodice with a long flared skirt."],
  ["Frock",        "Gathered skirt with a defined waist."],
  ["Kurti",        "Straight tunic, knee or calf length."],
  ["Blouse",       "Fitted short bodice."],
  ["Shirt",        "Collared shirt silhouette."],
  ["Other",        "Custom silhouette."]
].freeze

FABRICS = {
  "Cotton"    => { opacity: 1.0,  shine: 0.05, texture: "matte",       drape: "medium" },
  "Silk"      => { opacity: 1.0,  shine: 0.75, texture: "smooth",      drape: "fluid" },
  "Satin"     => { opacity: 1.0,  shine: 0.9,  texture: "glossy",      drape: "fluid" },
  "Linen"     => { opacity: 1.0,  shine: 0.05, texture: "slub",        drape: "stiff" },
  "Rayon"     => { opacity: 1.0,  shine: 0.35, texture: "smooth",      drape: "fluid" },
  "Velvet"    => { opacity: 1.0,  shine: 0.5,  texture: "pile",        drape: "heavy" },
  "Chiffon"   => { opacity: 0.65, shine: 0.2,  texture: "sheer",       drape: "airy" },
  "Georgette" => { opacity: 0.75, shine: 0.15, texture: "crepe",       drape: "airy" },
  "Denim"     => { opacity: 1.0,  shine: 0.05, texture: "twill",       drape: "stiff" }
}.freeze

PATTERNS = ["Plain", "Floral", "Printed", "Checks", "Stripes", "Paisley", "Polka Dots"].freeze

EMBROIDERY = [
  ["Zardosi",      "Metallic thread work with a raised finish."],
  ["Aari",         "Fine chain-stitch hook embroidery."],
  ["Mirror Work",  "Shisha mirrors set in thread."],
  ["Thread Work",  "Flat coloured thread motifs."],
  ["Sequin",       "Scattered or dense sequin fill."],
  ["Kantha",       "Running-stitch folk embroidery."]
].freeze

LACES = [
  ["Chantilly", "Fine floral net lace.",
   ["Fine floral pattern on a delicate net ground.",
    "Soft and light; the most bridal of the laces.",
    "Best used at the neckline and hem, not as a full panel."]],
  ["Crochet", "Open handmade-look lace.",
   ["Open, chunky loops with a handmade look.",
    "Casual and textural.",
    "Holds its shape well as a wide border."]],
  ["Scalloped", "Wavy edged trim.",
   ["Wavy scalloped edge along one side.",
    "Finishes a hem without a separate binding.",
    "The most versatile trim in the library."]],
  ["Beaded Lace", "Lace with bead detailing.",
   ["Lace ground with beads worked into the pattern.",
    "Catches light; heaviest of the trims.",
    "Reserve for occasion wear — it adds real weight."]],
  ["Ribbon Trim", "Flat woven ribbon.",
   ["Flat woven ribbon with a clean edge.",
    "Crisp and graphic rather than decorative.",
    "Good for defining a waist or panel seam."]]
].freeze

BELTS = [
  ["Slim Belt", 2.5,
   ["Narrow band, around 2.5 cm wide.",
    "Defines the waist without breaking the line.",
    "Subtle; works under a dupatta or jacket."]],
  ["Wide Belt", 6.0,
   ["Broad band, around 6 cm wide.",
    "Strongly cinches and shortens the torso.",
    "Best on full skirts and Anarkalis."]],
  ["Embellished Belt", 4.0,
   ["Mid-width band with stone or bead work.",
    "A focal point at the waist.",
    "Pair with a plain bodice so it isn't crowded."]],
  ["Fabric Sash", 8.0,
   ["Soft self-fabric tie, around 8 cm wide.",
    "Ties in a bow or knot; fully adjustable.",
    "The most forgiving option for a changing fit."]]
].freeze

BUTTONS = [
  ["Round", ["Classic circular button.",
             "The default; suits every garment.",
             "Sits flat and passes easily through a buttonhole."]],
  ["Square", ["Four straight edges with sharp corners.",
              "Modern and graphic.",
              "Best on structured fabrics and shirt plackets."]],
  ["Oval", ["Elongated rounded shape.",
            "Softer than square, more interesting than round.",
            "Reads as vertical, which lengthens a placket."]],
  ["Triangle", ["Three-sided decorative button.",
                "Distinctly ornamental rather than functional.",
                "Use sparingly — usually as an accent, not a full row."]]
].freeze

COLORS = {
  "Royal Purple" => "#7c3aed", "Deep Red" => "#dc2626", "Navy Blue" => "#1d4ed8",
  "Forest Green" => "#16a34a", "Rose Pink" => "#f43f5e", "Saffron" => "#f59e0b",
  "Turquoise" => "#0891b2", "Coral" => "#f97316", "Ivory" => "#fef3c7",
  "Black" => "#111827", "White" => "#f9fafb", "Gold" => "#d97706",
  "Magenta" => "#db2777", "Teal" => "#0d9488", "Maroon" => "#881337",
  "Sky Blue" => "#0ea5e9", "Peach" => "#fdba74", "Lavender" => "#c4b5fd",
  "Mint" => "#6ee7b7", "Blush" => "#fda4af"
}.freeze

# Pattern variants shown inside each style's collapsible section, four to a
# row with the description under the image.
#
#   [display name, slug, one-line description]
#
# The slug drives the thumbnail artwork; where a variant has no artwork of its
# own the frontend falls back to the parent style's sketch.
NECK_VARIANTS = {
  "high-neck" => [
    ["High Neck",   "high-neck",   "Cut close at the base of the throat."],
    ["Mock Neck",   "mock-neck",   "Short stand-up band, 3–4 cm high."],
    ["Turtle Neck", "turtle-neck", "Tall band folded back on itself."],
    ["Funnel Neck", "funnel-neck", "Wide collar flaring away from the neck."],
    ["Band Neck",   "band-neck",   "Narrow flat binding with no stand."]
  ],
  "collar-neck" => [
    ["Shirt Collar",    "shirt-collar",     "Pointed two-piece collar on a stand."],
    ["Mandarin Collar", "mandarin-collar",  "Short standing band; also called Chinese."],
    ["Peter Pan Collar","peter-pan-collar", "Flat collar with rounded ends."],
    ["Sailor Collar",   "sailor-collar",    "Square flap falling across the back."],
    ["Ruffle Collar",   "ruffle-collar",    "Gathered frill standing around the neck."]
  ],
  "halter-neck" => [
    ["Classic Halter", "halter-neck",    "Straps meet behind the neck."],
    ["Tie Halter",     "tie-halter",     "Fabric ties into a bow at the nape."],
    ["Keyhole Halter", "keyhole-halter", "Halter with a teardrop opening at the bust."],
    ["Cross Halter",   "cross-halter",   "Straps cross over before tying."]
  ],
  "round-neck" => [
    ["Crew Neck",  "round-neck",      "Sits right at the collarbone."],
    ["Jewel Neck", "jewel-neck",      "Higher and tighter than a crew."],
    ["Wide Round", "wide-round-neck", "Same depth, opened out toward the shoulders."],
    ["Deep Round", "deep-round-neck", "Classic curve dropped lower on the chest."]
  ],
  "u-neck" => [
    ["Classic U", "u-neck",       "Flat-bottomed U at mid-chest."],
    ["Shallow U", "shallow-u-neck", "A softer, higher version."],
    ["Deep U",    "deep-u-neck",  "Dropped well below the collarbone."],
    ["Wide U",    "wide-u-neck",  "Opened toward the shoulder points."]
  ],
  "v-neck" => [
    ["Classic V",  "v-neck",       "Tapers to a point at mid-chest."],
    ["Shallow V",  "shallow-v-neck", "A subtle V for daily wear."],
    ["Wide V",     "wide-v-neck",  "Broad V spanning the collarbones."],
    ["Surplice V", "surplice-neck", "Wrapped, one side crossing the other."]
  ],
  "deep-v-neck" => [
    ["Deep V",  "deep-v-neck",  "Drops below the bust line."],
    ["Plunge",  "plunge-neck",  "Narrow V continuing to the waist."],
    ["Cross Plunge", "cross-plunge-neck", "Deep V with crossed-over fronts."]
  ],
  "square-neck" => [
    ["Classic Square", "square-neck",      "Straight edge with squared corners."],
    ["Deep Square",    "deep-square-neck", "The same shape carried lower."],
    ["Wide Square",    "wide-square-neck", "Corners pushed out toward the shoulders."]
  ],
  "boat-neck" => [
    ["Classic Bateau", "boat-neck",       "Shallow curve, shoulder to shoulder."],
    ["Wide Boat",      "wide-boat-neck",  "Extended almost to the shoulder points."],
    ["Slit Boat",      "slit-boat-neck",  "Boat neck opened with a centre slit."]
  ],
  "off-shoulder" => [
    ["Off-Shoulder", "off-shoulder",  "Sits below both shoulders."],
    ["Bardot Band",  "bardot-neck",   "Wide elasticated band across the arms."],
    ["One-Shoulder", "one-shoulder",  "Covers one shoulder, leaves the other bare."]
  ],
  "sweetheart-neck" => [
    ["Sweetheart",      "sweetheart-neck",      "Two curves meeting in a soft point."],
    ["Semi-Sweetheart", "semi-sweetheart-neck", "A gentler curve; less pronounced."],
    ["Straight Sweetheart", "straight-sweetheart-neck", "Curved cups under a straight top edge."]
  ],
  "scoop-neck" => [
    ["Classic Scoop", "scoop-neck",      "Wide, deep, rounded curve."],
    ["Deep Scoop",    "deep-scoop-neck", "Carried lower down the chest."]
  ],
  "keyhole-neck" => [
    ["Teardrop Keyhole", "keyhole-neck",       "Closed collar with a teardrop cut-out."],
    ["Round Keyhole",    "round-keyhole-neck", "Circular opening below the collar."],
    ["Long Keyhole",     "long-keyhole-neck",  "Narrow slit running down the chest."]
  ]
}.freeze

def variants_for(slug, table)
  Array(table[slug]).map do |(name, variant_slug, description)|
    { "name" => name, "slug" => variant_slug, "description" => description }
  end
end

# Every pattern variant is a first-class DesignElement, not just a hash on its
# parent. That is what gives each one its own Active Storage slots (front /
# back / shadow) so a Super Admin can upload a real photo for "Mock Neck"
# rather than only for "High Neck".
#
# `metadata.variant_of` points at the parent's slug; the studio groups by it.
def upsert_variants!(category, parent_slug, table, admin, base_order)
  Array(table[parent_slug]).each_with_index do |(name, variant_slug, description), i|
    next if variant_slug == parent_slug # the parent already represents itself

    element = DesignElement.find_or_initialize_by(category: category, slug: variant_slug)
    element.assign_attributes(
      name: name,
      description: description,
      published: true,
      processing_status: "ready",
      created_by: admin,
      color_zone: category == "sleeve" ? "sleeve" : "bodice",
      sort_order: base_order * 100 + i,
      metadata: element.metadata.merge("variant_of" => parent_slug)
    )
    element.save!
  end
end

NECKLINES.each_with_index do |(name, description, characteristics), index|
  slug = name.parameterize
  upsert_element!("neck", name, admin, description: description, sort_order: index,
                                       color_zone: "bodice",
                                       metadata: {
                                         "characteristics" => characteristics,
                                         "variants" => variants_for(slug, NECK_VARIANTS)
                                       })
  upsert_variants!("neck", slug, NECK_VARIANTS, admin, index)
end

BACK_NECKLINES.each_with_index do |(name, description, characteristics), index|
  upsert_element!("back_neck", name, admin, description: description, sort_order: index,
                                            color_zone: "bodice",
                                            metadata: { "characteristics" => characteristics })
end

SLEEVE_VARIANTS = {
  "sleeveless" => [
    ["Plain Armhole", "sleeveless",          "Bound edge, cut on the shoulder line."],
    ["Deep Armhole",  "deep-armhole",        "Cut lower for a looser, cooler fit."],
    ["Halter Armhole", "halter-armhole",     "Narrow strap over the shoulder."]
  ],
  "cap-sleeve" => [
    ["Classic Cap",  "cap-sleeve",   "Small cap sitting on the shoulder."],
    ["Petal Cap",    "petal-cap",    "Two overlapping curved pieces."],
    ["Extended Cap", "extended-cap", "Longer cap reaching the upper arm."]
  ],
  "puff-sleeve" => [
    ["Classic Puff",  "puff-sleeve",  "Gathered at the shoulder, fitted below."],
    ["Double Puff",   "double-puff",  "Two tiers of gathering."],
    ["Juliet",        "juliet-sleeve", "Puffed shoulder over a fitted long sleeve."]
  ],
  "bell-sleeve" => [
    ["Classic Bell", "bell-sleeve",  "Flares evenly from the elbow."],
    ["Trumpet",      "trumpet-sleeve", "Fitted to the elbow, then flares sharply."],
    ["Tiered Bell",  "tiered-bell",  "Flare built from layered ruffles."]
  ],
  "flutter-sleeve" => [
    ["Single Flutter", "flutter-sleeve", "One loose ruffle over the arm."],
    ["Double Flutter", "double-flutter", "Two overlapping layers."],
    ["Cascade Flutter", "cascade-flutter", "Longer at the back than the front."]
  ],
  "full-sleeve" => [
    ["Straight Full", "full-sleeve",  "Even width to the wrist."],
    ["Fitted Full",   "fitted-full",  "Tapered close along the arm."],
    ["Cuffed Full",   "cuffed-full",  "Finished with a buttoned cuff."]
  ],
  "cold-shoulder" => [
    ["Strap Cold Shoulder", "cold-shoulder",     "Narrow strap holds the sleeve."],
    ["Tie Cold Shoulder",   "tie-cold-shoulder", "Shoulder gap closed with a tie."]
  ],
  "balloon-sleeve" => [
    ["Classic Balloon", "balloon-sleeve", "Rounded volume through the sleeve."],
    ["Cuffed Balloon",  "cuffed-balloon", "Volume gathered into a wrist cuff."]
  ]
}.freeze

SLEEVES.each_with_index do |(name, description, characteristics), index|
  slug = name.parameterize
  upsert_element!("sleeve", name, admin, description: description, sort_order: index,
                                         color_zone: "sleeve",
                                         metadata: {
                                           "characteristics" => characteristics,
                                           "variants" => variants_for(slug, SLEEVE_VARIANTS)
                                         })
  upsert_variants!("sleeve", slug, SLEEVE_VARIANTS, admin, index)
end

DRESS_TYPES.each_with_index do |(name, description), index|
  upsert_element!("dress_type", name, admin, description: description, sort_order: index,
                                             color_zone: "bodice")
end

FABRICS.each_with_index do |(name, props), index|
  upsert_element!("fabric", name, admin, sort_order: index, supports_color: false,
                                         opacity: props[:opacity], metadata: props.stringify_keys)
end

PATTERNS.each_with_index do |name, index|
  upsert_element!("pattern", name, admin, sort_order: index)
end

EMBROIDERY.each_with_index do |(name, description), index|
  upsert_element!("embroidery", name, admin, description: description, sort_order: index,
                                             color_zone: "embroidery",
                                             metadata: { "intensities" => %w[light heavy] })
end

LACES.each_with_index do |(name, description, characteristics), index|
  upsert_element!("lace", name, admin, description: description, sort_order: index,
                                       color_zone: "lace",
                                       metadata: { "default_width_cm" => 3,
                                                   "characteristics" => characteristics })
end

BELTS.each_with_index do |(name, width, characteristics), index|
  upsert_element!("belt", name, admin, sort_order: index, color_zone: "belt",
                                       description: "#{width} cm wide belt.",
                                       metadata: { "width_cm" => width,
                                                   "characteristics" => characteristics })
end

BUTTONS.each_with_index do |(shape, characteristics), index|
  upsert_element!("button", shape, admin, sort_order: index, color_zone: "buttons",
                                          description: "#{shape} button.",
                                          metadata: { "shape" => shape.downcase,
                                                      "placements" => %w[bodice skirt],
                                                      "characteristics" => characteristics })
end

COLORS.each_with_index do |(name, hex), index|
  upsert_element!("color", name, admin, sort_order: index, supports_color: false,
                                        metadata: { "hex" => hex })
end

puts "  design elements: #{DesignElement.count}"

# ── Compatibility rules ──────────────────────────────────────────
#
#   Halter Neck  → sleeves disabled entirely
#   High Neck    → only Full / 3-4 sleeves; back must stay High or Keyhole
#   Off-Shoulder → only Puff / Cap sleeves

def element(category, name) = DesignElement.find_by(category: category, slug: name.parameterize)

def rule!(source, target_category, mode, target: nil, note: nil)
  return if source.blank?

  CompatibilityRule.find_or_initialize_by(
    source_element: source, target_category: target_category,
    target_element: target, mode: mode
  ).tap { |r| r.note = note }.save!
end

halter = element("neck", "Halter Neck")
rule!(halter, "sleeve", "block_category", note: "A halter neckline leaves the shoulders bare")

high_neck = element("neck", "High Neck")
["Full Sleeve", "3/4 Sleeve"].each do |sleeve|
  rule!(high_neck, "sleeve", "allow", target: element("sleeve", sleeve))
end
["Deep U", "Deep V"].each do |back|
  rule!(high_neck, "back_neck", "block", target: element("back_neck", back),
        note: "A high front neckline needs a closed back")
end

off_shoulder = element("neck", "Off-Shoulder")
["Puff Sleeve", "Cap Sleeve"].each do |sleeve|
  rule!(off_shoulder, "sleeve", "allow", target: element("sleeve", sleeve))
end

sweetheart = element("neck", "Sweetheart Neck")
rule!(sweetheart, "sleeve", "block", target: element("sleeve", "Raglan Sleeve"),
      note: "A raglan seam cuts across the sweetheart line")

puts "  compatibility rules: #{CompatibilityRule.count}"

# ── Boutiques ────────────────────────────────────────────────────
[
  { name: "Silk Route Tailors", city: "Chennai", state: "Tamil Nadu",
    address_line: "12 Nungambakkam High Road", pincode: "600034",
    latitude: 13.0604, longitude: 80.2496, rating: 4.7, reviews_count: 212,
    phone: "+91 44 2822 1100", services: %w[bridal alterations blouse-fitting],
    description: "Bridal and occasion wear with in-house embroidery.",
    owner: User.find_by(email: "priya@tailortech.app") },
  { name: "Threadcraft Studio", city: "Hyderabad", state: "Telangana",
    address_line: "8-2-120 Banjara Hills", pincode: "500034",
    latitude: 17.4126, longitude: 78.4392, rating: 4.4, reviews_count: 97,
    phone: "+91 40 2354 8800", services: %w[fusion alterations express],
    description: "Fusion wear and quick turnaround alterations.",
    owner: User.find_by(email: "aisha@tailortech.app") },
  { name: "Kasavu House", city: "Kochi", state: "Kerala",
    address_line: "MG Road, Ravipuram", pincode: "682015",
    latitude: 9.9673, longitude: 76.2846, rating: 4.9, reviews_count: 340,
    phone: "+91 484 235 6677", services: %w[traditional saree-blouse kids],
    description: "Traditional Kerala garments, made to measure.",
    owner: User.find_by(email: "meera@tailortech.app") }
].each do |attrs|
  boutique = Boutique.find_or_initialize_by(name: attrs[:name])
  boutique.assign_attributes(attrs.merge(country: "India", active: true))
  boutique.save!
end

puts "  boutiques: #{Boutique.count}"

# ── A sample design + measurement so the app is not empty ────────
measurement = customer.measurements.find_or_initialize_by(name: "My Measurements")
measurement.assign_attributes(height: 163, bust: 88, waist: 71, hip: 96,
                              shoulder_width: 38, neck_size: 34,
                              sleeve_length: 56, dress_length: 132,
                              source: "manual", created_by: customer)
measurement.save!

design = customer.dress_designs.find_or_initialize_by(name: "Teal Anarkali")
design.assign_attributes(
  designer: designers.first,
  neck_type: "Sweetheart Neck", neck_back_type: "Deep U", sleeve_type: "3/4 Sleeve",
  dress_type: "Anarkali", fabric: "Georgette", pattern: "Floral",
  color: "#0d9488", bodice_color: "#0d9488", skirt_color: "#f59e0b",
  status: :completed, public_portfolio: true,
  components: {
    "neck" => { "front" => "Sweetheart Neck", "back" => "Deep U" },
    "colors" => {
      "bodice" => [{ "color" => "#0d9488", "direction" => "straight" }],
      "skirt" => [{ "color" => "#f59e0b", "direction" => "left_cross" },
                  { "color" => "#dc2626", "direction" => "curve" }]
    },
    "embroidery" => { "style" => "zardosi", "color" => "#d4a017",
                      "neck" => "heavy", "bodice_upper" => "light", "skirt_lower" => "heavy" },
    "lace" => { "style" => "scalloped", "color" => "#f0e6d3",
                "skirt_lower" => "light", "has_belt" => true }
  }
)
design.save!

puts "  designs: #{DressDesign.count}, measurements: #{Measurement.count}"
puts "→ Done. Sign in with any of:"
puts "   admin@tailortech.app / password123      (super admin)"
puts "   priya@tailortech.app / password123      (designer)"
puts "   customer@tailortech.app / password123   (customer)"
