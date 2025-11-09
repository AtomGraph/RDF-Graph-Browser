<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:dct="http://purl.org/dc/terms/"
    xmlns:ac="https://w3id.org/atomgraph/client#"
    xmlns:ldh="https://w3id.org/atomgraph/linkeddatahub#"
    exclude-result-prefixes="#all"
    extension-element-prefixes="ixsl"
    version="3.0">

    <!-- Key to lookup resources by URI or nodeID -->
    <xsl:key name="resources" match="*[*][@rdf:about] | *[*][@rdf:nodeID]" use="@rdf:about | @rdf:nodeID"/>

    <!-- Function to calculate node color from resource type URI(s) by averaging hues -->
    <xsl:function name="ldh:force-graph-3d-node-color" as="xs:string">
        <xsl:param name="resource" as="element()"/>

        <xsl:for-each select="$resource">
            <xsl:variable name="type-uris" select="rdf:type/@rdf:resource" as="xs:anyURI*"/>
            <xsl:choose>
                <xsl:when test="exists($type-uris)">
                    <xsl:variable name="hues" select="for $type in $type-uris return random-number-generator($type)?number * 360" as="xs:double*"/>
                    <xsl:variable name="avg-hue" select="avg($hues)" as="xs:double"/>
                    <!-- 70% saturation, 60% lightness = vibrant colors visible on black background -->
                    <xsl:sequence select="'hsl(' || $avg-hue || ', 70%, 60%)'"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- Default gray for resources without type -->
                    <xsl:sequence select="'#95a5a6'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>

    <xsl:function name="ac:label" as="xs:string">
        <xsl:param name="resource" as="element()"/>

        <xsl:for-each select="$resource">
            <xsl:choose>
                <xsl:when test="foaf:name[not(@rdf:resource)]">
                    <xsl:sequence select="string(foaf:name[1])"/>
                </xsl:when>
                <xsl:when test="rdfs:label[not(@rdf:resource)]">
                    <xsl:sequence select="string(rdfs:label[1])"/>
                </xsl:when>
                <xsl:when test="dct:title[not(@rdf:resource)]">
                    <xsl:sequence select="string(dct:title[1])"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- Fallback: use last segment of rdf:about, or rdf:nodeID for blank nodes -->
                    <xsl:sequence select="if (@rdf:about) then tokenize(@rdf:about, '[/#]')[last()] else @rdf:nodeID"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>

    <!-- Initialize 3D Force Graph -->
    <xsl:template name="ldh:ForceGraph3D-init">
        <xsl:param name="graph-id" as="xs:string"/> <!-- string: graph container element ID -->
        <xsl:param name="container" as="element()"/> <!-- HTMLElement: DOM element for graph -->
        <xsl:param name="builder" as="item()"/> <!-- function: ForceGraph3D constructor -->
        <xsl:param name="graph-width" as="xs:double"/> <!-- number: canvas width in px -->
        <xsl:param name="graph-height" as="xs:double"/> <!-- number: canvas height in px -->
        <xsl:param name="node-rel-size" as="xs:double"/> <!-- number: relative node size -->
        <xsl:param name="link-width" as="xs:double"/> <!-- number: link line width in px -->
        <xsl:param name="node-label-color" as="xs:string"/> <!-- string: CSS color for node labels -->
        <xsl:param name="node-label-text-height" as="xs:double"/> <!-- number: node label font size -->
        <xsl:param name="node-label-position-y" as="xs:double"/> <!-- number: node label Y offset -->
        <xsl:param name="link-label-color" as="xs:string"/> <!-- string: CSS color for link labels -->
        <xsl:param name="link-label-text-height" as="xs:double"/> <!-- number: link label font size -->
        <xsl:param name="link-force-distance" as="xs:double"/> <!-- number: target distance between linked nodes -->
        <xsl:param name="charge-force-strength" as="xs:double"/> <!-- number: node repulsion strength (negative) -->

        <!-- Optional JavaScript function parameters - callers can override default behavior -->
        <xsl:param name="nodeLabel-fn" select="ixsl:eval('() => null')" as="item()?"/> <!-- function: node label accessor -->
        <xsl:param name="nodeColor-fn" select="ixsl:eval('node => node.color')" as="item()?"/> <!-- function: node color accessor -->
        <xsl:param name="nodeThreeObject-fn" as="item()?"> <!-- function: custom Three.js object for nodes -->
            <xsl:variable name="js-statement" as="element()">
                <root statement="node => {{
                    const sprite = new SpriteText(node.label);
                    sprite.material.depthWrite = false;
                    sprite.color = '{$node-label-color}';
                    sprite.textHeight = {$node-label-text-height};
                    sprite.position.y = {$node-label-position-y};
                    return sprite;
                }}"/>
            </xsl:variable>
            <xsl:sequence select="ixsl:eval(string($js-statement/@statement))"/>
        </xsl:param>
        <xsl:param name="linkThreeObject-fn" as="item()?"> <!-- function: custom Three.js object for links -->
            <xsl:variable name="js-statement" as="element()">
                <root statement="link => {{
                    const sprite = new SpriteText(link.label);
                    sprite.material.depthWrite = false;
                    sprite.color = '{$link-label-color}';
                    sprite.textHeight = {$link-label-text-height};
                    return sprite;
                }}"/>
            </xsl:variable>
            <xsl:sequence select="ixsl:eval(string($js-statement/@statement))"/>
        </xsl:param>
        <xsl:param name="linkPositionUpdate-fn" select="ixsl:eval('(sprite, { start, end }) => {
            if (!sprite) return;
            const middlePos = Object.assign({},
                ...[''x'', ''y'', ''z''].map(c => ({
                    [c]: start[c] + (end[c] - start[c]) / 2
                }))
            );
            Object.assign(sprite.position, middlePos);
        }')" as="item()?"/> <!-- function: link sprite position updater -->
        <xsl:param name="onNodeClick-fn" as="item()?"> <!-- function: node click handler -->
            <xsl:variable name="js-statement" as="element()">
                <root statement="node => {{
                    var graphState = window.LinkedDataHub.graphs['{$graph-id}'];
                    var now = new Date().getTime();
                    var lastClick = graphState.lastNodeClickTime || 0;
                    var timeDiff = now - lastClick;
                    graphState.lastNodeClickTime = now;
                    if (timeDiff > 0 &amp;&amp; timeDiff &lt; 500) {{
                        var event = new CustomEvent('ForceGraph3DNodeDblClick', {{
                            detail: {{
                                canvasId: '{$graph-id}',
                                nodeId: node.id,
                                nodeLabel: node.label,
                                nodeType: node.type
                            }}
                        }});
                        document.dispatchEvent(event);
                    }} else {{
                        var event = new CustomEvent('ForceGraph3DNodeClick', {{
                            detail: {{
                                canvasId: '{$graph-id}',
                                nodeId: node.id,
                                nodeLabel: node.label,
                                nodeType: node.type
                            }}
                        }});
                        document.dispatchEvent(event);
                    }}
                }}"/>
            </xsl:variable>
            <xsl:sequence select="ixsl:eval(string($js-statement/@statement))"/>
        </xsl:param>
        <xsl:param name="onNodeRightClick-fn" as="item()?"> <!-- function: node right-click handler -->
            <xsl:variable name="js-statement" as="element()">
                <root statement="node => {{
                    let event = new CustomEvent('ForceGraph3DNodeRightClick', {{
                        detail: {{
                            canvasId: '{$graph-id}',
                            nodeId: node.id,
                            nodeLabel: node.label
                        }}
                    }});
                    document.dispatchEvent(event);
                }}"/>
            </xsl:variable>
            <xsl:sequence select="ixsl:eval(string($js-statement/@statement))"/>
        </xsl:param>
        <xsl:param name="onNodeHover-fn-factory" as="item()?"> <!-- function: creates node hover handler -->
            <xsl:variable name="js-statement" as="element()">
                <root statement="(graphInstance) => {{
                    return (node) => {{
                        if (node) {{
                            const screenCoords = graphInstance.graph2ScreenCoords(node.x, node.y, node.z);
                            let event = new CustomEvent('ForceGraph3DNodeHoverOn', {{
                                detail: {{
                                    canvasId: '{$graph-id}',
                                    nodeId: node.id,
                                    nodeLabel: node.label,
                                    nodeType: node.type,
                                    screenX: screenCoords.x,
                                    screenY: screenCoords.y
                                }}
                            }});
                            document.dispatchEvent(event);
                        }} else {{
                            let event = new CustomEvent('ForceGraph3DNodeHoverOff', {{
                                detail: {{
                                    canvasId: '{$graph-id}'
                                }}
                            }});
                            document.dispatchEvent(event);
                        }}
                    }};
                }}"/>
            </xsl:variable>
            <xsl:sequence select="ixsl:eval(string($js-statement/@statement))"/>
        </xsl:param>
        <xsl:param name="onLinkClick-fn" as="item()?"> <!-- function: link click handler -->
            <xsl:variable name="js-statement" as="element()">
                <root statement="link => {{
                    let event = new CustomEvent('ForceGraph3DLinkClick', {{
                        detail: {{
                            canvasId: '{$graph-id}',
                            sourceId: link.source.id,
                            targetId: link.target.id,
                            linkLabel: link.label
                        }}
                    }});
                    document.dispatchEvent(event);
                }}"/>
            </xsl:variable>
            <xsl:sequence select="ixsl:eval(string($js-statement/@statement))"/>
        </xsl:param>
        <xsl:param name="onBackgroundClick-fn" as="item()?"> <!-- function: background click handler -->
            <xsl:variable name="js-statement" as="element()">
                <root statement="() => {{
                    let event = new CustomEvent('ForceGraph3DBackgroundClick', {{
                        detail: {{
                            canvasId: '{$graph-id}'
                        }}
                    }});
                    document.dispatchEvent(event);
                }}"/>
            </xsl:variable>
            <xsl:sequence select="ixsl:eval(string($js-statement/@statement))"/>
        </xsl:param>

        <!-- Create the graph instance -->
        <xsl:variable name="graph" select="ixsl:apply($builder, [ $container ])" as="item()"/>

        <!-- Configure graph -->
        <xsl:variable name="graph" select="if (exists($nodeLabel-fn)) then ixsl:call($graph, 'nodeLabel', [ $nodeLabel-fn ]) else $graph"/>
        <xsl:variable name="graph" select="if (exists($nodeColor-fn)) then ixsl:call($graph, 'nodeColor', [ $nodeColor-fn ]) else $graph"/>
        <xsl:variable name="graph" select="ixsl:call($graph, 'nodeRelSize', [ $node-rel-size ])"/>
        <xsl:variable name="graph" select="ixsl:call($graph, 'linkWidth', [ $link-width ])"/>

        <!-- Configure labels to be always visible -->
        <xsl:variable name="graph" select="if (exists($nodeThreeObject-fn)) then ixsl:call($graph, 'nodeThreeObjectExtend', [ true() ]) else $graph"/>
        <xsl:variable name="graph" select="if (exists($nodeThreeObject-fn)) then ixsl:call($graph, 'nodeThreeObject', [ $nodeThreeObject-fn ]) else $graph"/>

        <xsl:variable name="graph" select="if (exists($linkThreeObject-fn)) then ixsl:call($graph, 'linkThreeObjectExtend', [ true() ]) else $graph"/>
        <xsl:variable name="graph" select="if (exists($linkThreeObject-fn)) then ixsl:call($graph, 'linkThreeObject', [ $linkThreeObject-fn ]) else $graph"/>

        <xsl:variable name="graph" select="if (exists($linkPositionUpdate-fn)) then ixsl:call($graph, 'linkPositionUpdate', [ $linkPositionUpdate-fn ]) else $graph"/>

        <!-- Set up event handlers (only if provided) -->
        <xsl:variable name="graph" select="if (exists($onNodeClick-fn)) then ixsl:call($graph, 'onNodeClick', [ $onNodeClick-fn ], map{ 'convert-args': false() }) else $graph"/>
        <xsl:variable name="graph" select="if (exists($onNodeRightClick-fn)) then ixsl:call($graph, 'onNodeRightClick', [ $onNodeRightClick-fn ], map{ 'convert-args': false() }) else $graph"/>

        <!-- Create hover handler with graph instance in closure -->
        <xsl:variable name="onNodeHover-fn" select="if (exists($onNodeHover-fn-factory)) then ixsl:apply($onNodeHover-fn-factory, [ $graph ]) else ()"/>
        <xsl:variable name="graph" select="if (exists($onNodeHover-fn)) then ixsl:call($graph, 'onNodeHover', [ $onNodeHover-fn ], map{ 'convert-args': false() }) else $graph"/>

        <xsl:variable name="graph" select="if (exists($onLinkClick-fn)) then ixsl:call($graph, 'onLinkClick', [ $onLinkClick-fn ], map{ 'convert-args': false() }) else $graph"/>
        <xsl:variable name="graph" select="if (exists($onBackgroundClick-fn)) then ixsl:call($graph, 'onBackgroundClick', [ $onBackgroundClick-fn ], map{ 'convert-args': false() }) else $graph"/>

        <!-- Configure force simulation -->
        <xsl:variable name="link-force" select="ixsl:call($graph, 'd3Force', [ 'link' ])"/>
        <xsl:sequence select="ixsl:call($link-force, 'distance', [ $link-force-distance ])[current-date() lt xs:date('2000-01-01')]"/>
        <xsl:variable name="charge-force" select="ixsl:call($graph, 'd3Force', [ 'charge' ])"/>
        <xsl:sequence select="ixsl:call($charge-force, 'strength', [ $charge-force-strength ])[current-date() lt xs:date('2000-01-01')]"/>

        <!-- Create and return graph state -->
        <xsl:variable name="graph-state" select="ixsl:eval('({})')"/>
        <xsl:for-each select="$graph-state">
            <ixsl:set-property name="instance" select="$graph" object="."/>
            <ixsl:set-property name="showLabels" select="false()" object="."/>
        </xsl:for-each>
        <!-- Return the graph state for further use -->
        <xsl:sequence select="$graph-state"/>
    </xsl:template>

    <!-- Convert RDF/XML to Force Graph data structure -->
    <xsl:template match="/" mode="ldh:ForceGraph3D-convert-data" as="item()">
        <!-- Expects pre-normalized RDF/XML (all nested structures flattened, URIs resolved) -->
        <!-- Process RDF to get nodes and links -->
        <xsl:variable name="nodes" as="item()*">
            <xsl:apply-templates select="rdf:RDF" mode="ldh:ForceGraph3D-nodes"/>
        </xsl:variable>
        <xsl:variable name="links" as="item()*">
            <xsl:apply-templates select="rdf:RDF" mode="ldh:ForceGraph3D-links"/>
        </xsl:variable>
        <!-- Create graph data object with empty arrays -->
        <xsl:variable name="graph-data" select="ixsl:eval('({ nodes: [], links: [] })')"/>

        <!-- Get arrays from the object -->
        <xsl:variable name="nodes-array" select="ixsl:get($graph-data, 'nodes', map{ 'convert-result': false() })"/>
        <xsl:variable name="links-array" select="ixsl:get($graph-data, 'links', map{ 'convert-result': false() })"/>

        <!-- Populate JavaScript arrays -->
        <xsl:for-each select="$nodes">
            <xsl:sequence select="ixsl:call($nodes-array, 'push', [ . ], map{ 'convert-args': false() })[current-date() lt xs:date('2000-01-01')]"/>
        </xsl:for-each>
        <xsl:for-each select="$links">
            <xsl:sequence select="ixsl:call($links-array, 'push', [ . ], map{ 'convert-args': false() })[current-date() lt xs:date('2000-01-01')]"/>
        </xsl:for-each>

        <xsl:sequence select="$graph-data"/>
    </xsl:template>

    <!-- NODE MODE TEMPLATES -->

    <!-- rdf:RDF level - nodes mode -->
    <xsl:template match="rdf:RDF" mode="ldh:ForceGraph3D-nodes" as="item()*">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <!-- rdf:Description level - nodes mode -->
    <xsl:template match="rdf:Description[@rdf:about or @rdf:nodeID]" mode="ldh:ForceGraph3D-nodes" as="item()">
        <xsl:param name="label" select="ac:label(.)" as="xs:string"/> <!-- string: display label for the node -->
        <xsl:param name="type-uri" select="rdf:type[1]/@rdf:resource" as="xs:string?"/> <!-- string?: full URI of node type -->
        <xsl:param name="type-local" select="if ($type-uri) then tokenize($type-uri, '[/#]')[last()] else 'Resource'" as="xs:string"/> <!-- string: local name of type -->
        <xsl:param name="color" select="ldh:force-graph-3d-node-color(.)" as="xs:string"/> <!-- string: CSS color for node -->
        <xsl:variable name="id" select="(@rdf:about, @rdf:nodeID)[1]" as="xs:string"/>

        <!-- Create node object -->
        <xsl:variable name="node" select="ixsl:eval('{}')"/>
        <xsl:for-each select="$node">
            <ixsl:set-property name="id" select="$id" object="."/>
            <ixsl:set-property name="label" select="$label" object="."/>
            <ixsl:set-property name="type" select="$type-local" object="."/>
            <ixsl:set-property name="color" select="$color" object="."/>
        </xsl:for-each>

        <xsl:sequence select="$node"/>
    </xsl:template>

    <!-- Suppress text nodes in nodes mode -->
    <xsl:template match="text()" mode="ldh:ForceGraph3D-nodes"/>

    <!-- LINKS MODE TEMPLATES -->

    <!-- rdf:RDF level - links mode -->
    <xsl:template match="rdf:RDF" mode="ldh:ForceGraph3D-links" as="item()*">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <!-- rdf:Description level - links mode -->
    <xsl:template match="rdf:Description[@rdf:about or @rdf:nodeID]" mode="ldh:ForceGraph3D-links" as="item()*">
        <xsl:variable name="id" select="(@rdf:about, @rdf:nodeID)[1]" as="xs:string"/>

        <xsl:apply-templates select="*[@rdf:resource or @rdf:nodeID]" mode="#current">
            <xsl:with-param name="source-id" select="$id"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- Property level - links mode -->
    <xsl:template match="rdf:Description/*[@rdf:resource or @rdf:nodeID]" mode="ldh:ForceGraph3D-links" as="item()?">
        <xsl:param name="source-id" as="xs:string"/>

        <xsl:variable name="target" select="(@rdf:resource, @rdf:nodeID)[1]" as="xs:string"/>
        <xsl:variable name="link-label" select="local-name()" as="xs:string"/>

        <!-- Check if target resource exists in the RDF graph -->
        <xsl:if test="key('resources', $target)">
            <!-- Create and return link object -->
            <xsl:variable name="link" select="ixsl:eval('{}')"/>
            <xsl:for-each select="$link">
                <ixsl:set-property name="source" select="$source-id" object="."/>
                <ixsl:set-property name="target" select="$target" object="."/>
                <ixsl:set-property name="label" select="$link-label" object="."/>
            </xsl:for-each>

            <xsl:sequence select="$link"/>
        </xsl:if>
    </xsl:template>

    <!-- Suppress text nodes in links mode -->
    <xsl:template match="text()" mode="ldh:ForceGraph3D-links"/>

</xsl:stylesheet>
