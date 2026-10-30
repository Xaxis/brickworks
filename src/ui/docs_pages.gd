## The docs page of each panel the window opens, which Help, Documentation
## opens while that panel is in front (Shell.docs_page): made by
## tools/docs_site.py --write from the `panels:` in docs-site's page heads.
## Edit those, not this; tests/test_docs_site.py fails while the two differ.
class_name DocsPages

const SITE := "https://brickworks.diy"

const PANELS := {
	"AccountPanel": "/docs/account#account-panel",
	"AiSettings": "/docs/ai#other-ais",
	"BrickifyDialog": "/docs/art-and-brickify#brickify",
	"BuildMode": "/docs/model-pages#build-it",
	"ClaudeTabView": "/docs/connector#tabs",
	"CollectionDialog": "/docs/collection#my-collection",
	"ControlsDialog": "/docs/panels-and-settings#settings",
	"ElementDialog": "/docs/figures-and-prints#make-a-part",
	"HiddenColoursPanel": "/docs/joints-and-mechanisms#hidden-colours",
	"LibraryDialog": "/docs/saving-and-files#library",
	"MinifigDialog": "/docs/figures-and-prints#minifig",
	"MosaicDialog": "/docs/art-and-brickify#mosaic",
	"MouldEditor": "/docs/figures-and-prints#mould",
	"PageEditor": "/docs/instructions#lay-out",
	"PatternDialog": "/docs/building#patterns",
	"PosePanel": "/docs/joints-and-mechanisms#motions",
	"PrintEditor": "/docs/figures-and-prints#prints",
	"RenderDialog": "/docs/exports#render",
	"SavedModelsDialog": "/docs/saving-and-files#open",
	"SharePanel": "/docs/sharing#share",
	"ShareView": "/docs/model-pages#viewer",
	"SimulatePanel": "/docs/joints-and-mechanisms#simulate",
	"TogetherDialog": "/docs/build-together",
	"VersionsDialog": "/docs/saving-and-files#versions",
}
