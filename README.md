# 3D Linked Data

A browser-based RDF graph visualization tool that combines:
- **3d-force-graph** - 3D force-directed graph visualization using WebGL/three.js
- **SaxonJS 3.0** - Client-side XSLT 3.0 processor
- **RDF/XML** - Semantic Web data format

> **⚠️ Important Limitation:** Currently, only documents that return `application/rdf+xml` content type can be loaded. Other RDF formats (Turtle, JSON-LD, N-Triples) are not yet supported.

## Features

- **Load RDF documents** - Enter any HTTP(S) URL to load and visualize RDF/XML data
- **3D visualization** - Interactive 3D force-directed graph with color-coded nodes by type
- **Navigate graphs** - Double-click nodes to load and explore linked RDF resources
- **Inspect resources** - Click nodes to view their RDF properties
- **XSLT-driven** - All logic implemented in client-side XSLT 3.0

## Project Structure

```
3D-Linked-Data/
├── index.html              # Main HTML page
├── styles.css              # External stylesheet
├── generate-sef.sh         # Script to compile XSLT to SEF
├── lib/                    # External libraries
│   └── SaxonJS3.js        # SaxonJS 3.0 library
├── src/                    # XSLT source files
│   ├── graph-client.xsl   # Main XSLT client with event handlers
│   ├── 3d-force-graph.xsl # 3D Force Graph initialization
│   ├── normalize-rdfxml.xsl # RDF/XML normalization
│   └── merge-rdfxml.xsl   # RDF document merging
└── dist/                   # Compiled output
    └── graph-client.xsl.sef.json # Compiled SEF for SaxonJS
```

## Dependencies

### From CDN
- **[3d-force-graph](https://github.com/vasturiano/3d-force-graph)** (v1.73.3) - 3D force-directed graph visualization (includes three.js)
- **three-spritetext** - Text sprites for 3D labels

### Local
- **[SaxonJS 3.0](https://www.saxonica.com/saxonjs/index.xml)** - `lib/SaxonJS3.js`

## Setup

### Prerequisites

- Node.js and npm installed
- `xslt3-he` package (for compiling XSLT to SEF)

Install xslt3-he if needed:
```bash
npm install -g xslt3-he
```

### Generate SEF file

If you modify the XSLT, regenerate the SEF file:

```bash
./generate-sef.sh
```

## Usage

### Loading RDF Documents

1. **Default**: On page load, `https://linkeddatahub.com/demo/skos/concepts/concept17128/` is loaded automatically via CORS proxy
2. **Custom URL**: Enter any HTTP(S) URL in the input field and click "Go" or press Enter (automatically proxied)
3. **Navigate**: Double-click any HTTP(S) node to either:
   - Load that resource via HTTP (if not already loaded)
   - Expand its linked resources as stub nodes (if already loaded)

### Interactive Features

- **Single-click node** - View resource details in info panel
- **Double-click node** - Load and visualize that node's RDF document
- **Hover node** - Show tooltip with node label and type
- **Drag node** - Reposition nodes in 3D space
- **Rotate view** - Click and drag background to rotate
- **Zoom** - Mouse wheel to zoom in/out
- **Reset Camera** - Button to return to default view

### Developer Console

All events and operations are logged to the browser console using `<xsl:message>` from XSLT templates. Open the browser's developer console to see:
- RDF document loading
- Graph updates
- Node interactions
- Error messages

## Architecture

### XSLT-Driven Design

Unlike typical web applications where JavaScript handles all logic, this application uses XSLT 3.0 for everything:

**What XSLT does (not JavaScript):**
- Loads RDF documents via HTTP
- Parses and normalizes RDF/XML
- Merges RDF data from multiple sources
- Handles UI events (clicks, double-clicks, hovers)
- Updates the DOM (info panel, tooltips)
- Converts RDF to graph visualization data
- Controls the 3D Force Graph

**How it works:**
- XSLT source files in `src/` are compiled to SEF format by `generate-sef.sh`
- SaxonJS loads the pre-compiled SEF and executes XSLT in the browser
- XSLT uses SaxonJS interactive extensions (`ixsl:*`) to interact with JavaScript, DOM, and HTTP APIs

**Why this approach:**
- Declarative programming model for semantic data processing
- Built-in RDF/XML handling without parsing libraries
- Pattern matching via templates and modes
- XPath 3.1 for querying RDF structures

### Event Flow

1. **Page Load**
   - SaxonJS loads pre-compiled SEF file
   - XSLT `main` template initializes 3D Force Graph
   - Default RDF document is loaded via `ixsl:http-request()`

2. **User Interaction**
   - User clicks/hovers/double-clicks node in 3D graph
   - JavaScript event handler creates `CustomEvent` with node details
   - Event dispatched to `document`
   - XSLT template in `ixsl:on*` mode handles event
   - XSLT manipulates DOM using `ixsl:set-style`, `xsl:result-document`

3. **RDF Loading**
   - User enters URL or double-clicks node
   - XSLT calls `load-and-update-graph` template
   - `ixsl:http-request()` with `'pool': 'xml'` fetches and caches RDF
   - RDF/XML is normalized (3 passes)
   - Converted to 3D Force Graph JSON format
   - Graph visualization updated

### Key XSLT Features Used

- **IXSL extensions** - DOM manipulation, HTTP requests, JavaScript interop
- **Promises** - Async RDF loading with `ixsl:promise`
- **Document pool** - Caching fetched RDF with `'pool': 'xml'`
- **Keys** - Fast RDF resource lookup with `key('resources', ...)`
- **Custom events** - Bridge between 3D Force Graph and XSLT
- **Mode templates** - Event handler dispatch

## How It Works

### RDF to Graph Conversion

The XSLT pipeline converts RDF/XML to the format expected by 3d-force-graph:

1. **Normalize RDF/XML** (`normalize-rdfxml.xsl`)
   - Normalize syntax (striped/node-centric → node-centric only)
   - Flatten blank nodes
   - Resolve relative URIs to absolute

2. **Extract Nodes and Links** (`ldh:ForceGraph3D-convert-data` mode)
   - Resources with `rdf:about` → nodes
   - Properties with `rdf:resource` → links
   - Node colors based on `rdf:type` (hashed from type URI)
   - Labels from `foaf:name`, `rdfs:label`, `dct:title`, or URI fragment

3. **Update Graph**
   - Call `graph.graphData()` with JSON structure
   - Graph re-renders with force simulation

## Troubleshooting

### SEF file not found
Run `./generate-sef.sh` to compile the XSLT to SEF format

## License

This project uses:
- SaxonJS - Mozilla Public License 2.0
- 3d-force-graph - MIT License
