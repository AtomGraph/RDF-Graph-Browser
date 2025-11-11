# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an RDF graph visualization tool that runs entirely in the browser. It combines 3D force-directed graph visualization (using WebGL/three.js) with client-side XSLT 3.0 processing (SaxonJS) to render and navigate RDF/XML semantic web data.

**Key architectural principle**: All application logic is implemented in XSLT 3.0, not JavaScript. The XSLT runs in the browser via SaxonJS and handles everything from RDF loading to DOM manipulation to event handling.

## Development Commands

### Compile XSLT to SEF format
```bash
./generate-sef.sh
```

This compiles `src/graph-client.xsl` (and its imports) to `dist/graph-client.xsl.sef.json`. The SEF (Saxon Export Format) file is what SaxonJS loads and executes in the browser.

**Run this command whenever you modify any `.xsl` file in `src/`.**

### Local development server
No build system is required. Simply serve the directory with any HTTP server:
```bash
python3 -m http.server 8000
# or
npx http-server
```

Then open `http://localhost:8000` in a browser.

### Installing xslt3-he (if needed)
```bash
npm install -g xslt3-he
```

## Architecture

### XSLT-Driven Design

This application is unique: all logic lives in XSLT, not JavaScript. The architecture is:

1. **index.html** - Minimal HTML shell that loads:
   - three.js and 3d-force-graph from CDN
   - SaxonJS 3.0 (`lib/SaxonJS3.js`)
   - Compiled XSLT (`dist/graph-client.xsl.sef.json`)

2. **src/graph-client.xsl** - Main XSLT stylesheet that:
   - Initializes the 3D force graph on page load
   - Handles all UI events (clicks, double-clicks, hovers)
   - Loads RDF documents via HTTP
   - Manipulates the DOM
   - Imports the other two stylesheets

3. **src/3d-force-graph.xsl** - 3D graph initialization and configuration:
   - Creates the ForceGraph3D instance
   - Sets up node/link rendering (colors, labels, Three.js objects)
   - Registers JavaScript event handlers that dispatch CustomEvents back to XSLT
   - Converts RDF/XML to graph JSON format

4. **src/normalize-rdfxml.xsl** - RDF/XML normalization pipeline:
   - Three-pass normalization: syntax → flattening → URI resolution
   - Converts all RDF syntax variants to canonical form
   - Resolves relative URIs to absolute URIs

### Event Flow

```
User interacts with 3D graph (click/hover/double-click node)
  ↓
JavaScript event handler in 3d-force-graph.xsl creates CustomEvent
  ↓
CustomEvent dispatched to document
  ↓
XSLT template with ixsl:on* attribute catches event
  ↓
XSLT processes event (loads new RDF, updates DOM, etc.)
  ↓
XSLT calls graph.graphData() to update visualization
```

### RDF Loading and Graph Updates

When a URI is loaded (on page load or via double-click):

1. XSLT template `load-and-update-graph` is called with a document URI
2. Uses `ixsl:http-request()` with `'pool': 'xml'` to fetch and cache RDF/XML
3. RDF goes through 3-pass normalization (normalize-rdfxml.xsl)
4. Normalized RDF is converted to graph JSON using `ldh:ForceGraph3D-convert-data` mode templates
5. Graph data structure: `{ nodes: [{id, label, color, ...}], links: [{source, target, label, ...}] }`
6. XSLT calls `graph.graphData(newData)` to update the 3D visualization

### Key XSLT/IXSL Features

This codebase heavily uses SaxonJS interactive XSLT features:

- **ixsl:get()**, **ixsl:set-property()** - JavaScript object property access
- **ixsl:call()**, **ixsl:apply()** - JavaScript function calls
- **ixsl:http-request()** - Async HTTP with promises
- **ixsl:eval()** - Evaluate JavaScript expressions
- **ixsl:page()**, **id()** - DOM access
- **xsl:result-document** with `method="ixsl:append-content"` - DOM manipulation
- **ixsl:on**** attributes - Event handling templates
- **key()** - Fast RDF resource lookup by URI
- **Mode templates** - Dispatch pattern for different processing phases

### State Management

Graph state is stored in `window.LinkedDataHub.graphs[graph-id]` and contains:
- `graph` - The ForceGraph3D instance
- `currentDocumentURI` - URI of currently loaded RDF document
- `resources` - Cached RDF document (optional)

Access via helper functions in graph-client.xsl:
- `local:get-graphs()` - Returns the graphs object
- `local:get-graph-state($graph-id)` - Returns state for a specific graph

## Modifying the Application

### Adding new XSLT logic

1. Edit the appropriate `.xsl` file in `src/`:
   - Event handling → `src/graph-client.xsl`
   - Graph rendering → `src/3d-force-graph.xsl`
   - RDF processing → `src/normalize-rdfxml.xsl`

2. Run `./generate-sef.sh` to recompile

3. Refresh the browser (hard refresh if needed)

### Adding UI event handlers

To handle new graph events in XSLT:

1. In `src/3d-force-graph.xsl`, add a JavaScript event handler that dispatches a CustomEvent:
   ```javascript
   .onNodeSomeEvent(node => {
     document.dispatchEvent(new CustomEvent('graph-node-someevent', {
       detail: { graphId: graphId, node: node }
     }));
   })
   ```

2. In `src/graph-client.xsl`, add an XSLT template to handle the event:
   ```xml
   <xsl:template match="/" mode="ixsl:ongraph-node-someevent">
     <xsl:variable name="node" select="ixsl:get(ixsl:event(), 'detail.node')"/>
     <!-- Your logic here -->
   </xsl:template>
   ```

### Changing graph appearance

Graph visual parameters are in the `main` template in `src/graph-client.xsl`:
- `node-rel-size` - Node size
- `link-width` - Link line width
- `node-label-*` - Node label styling
- `link-label-*` - Link label styling
- `link-force-distance` - Target distance between linked nodes
- `charge-force-strength` - Node repulsion strength (negative value)

Node colors are determined by `ldh:force-graph-3d-node-color()` in `src/3d-force-graph.xsl`, which hashes rdf:type URIs to HSL colors.

### Debugging

All XSLT operations are logged to the browser console using `<xsl:message>`. Open DevTools to see:
- RDF loading progress
- Normalization passes
- Graph updates
- Event handling
- Errors

The SaxonJS transform uses `logLevel: 10` for verbose logging.

## Testing with Sample Data

The `examples/` directory contains sample RDF files. To test with different RDF:

1. Add an `.rdf` file to `examples/`
2. Change the `document-uri` parameter in the `main` template in `src/graph-client.xsl`
3. Recompile and refresh

Or enter any HTTP(S) URL in the UI input field. The remote server must send CORS headers.

## Common Patterns

### Loading RDF from a URI
```xml
<xsl:call-template name="load-and-update-graph">
  <xsl:with-param name="graph-id" select="$graph-id"/>
  <xsl:with-param name="document-uri" select="xs:anyURI('http://example.org/data.rdf')"/>
</xsl:call-template>
```

### Accessing graph instance
```xml
<xsl:variable name="graph-state" select="local:get-graph-state($graph-id)"/>
<xsl:variable name="graph" select="ixsl:get($graph-state, 'graph')"/>
```

### Updating graph data
```xml
<xsl:variable name="new-data" select="/* converted to JSON map */"/>
<xsl:sequence select="ixsl:call($graph, 'graphData', [$new-data])"/>
```

### DOM manipulation
```xml
<xsl:for-each select="id('info-panel', ixsl:page())">
  <xsl:result-document href="?." method="ixsl:replace-content">
    <div>New content here</div>
  </xsl:result-document>
</xsl:for-each>
```
