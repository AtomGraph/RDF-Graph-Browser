<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:dct="http://purl.org/dc/terms/"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:ac="https://w3id.org/atomgraph/client#"
    exclude-result-prefixes="#all"
    version="3.0">

    <!-- Key to lookup resources by URI or nodeID -->
    <xsl:key name="resources" match="*[*][@rdf:about] | *[*][@rdf:nodeID]" use="@rdf:about | @rdf:nodeID"/>

    <!-- Key for looking up resources by @rdf:about -->
    <xsl:key name="resources" match="rdf:Description[@rdf:about]" use="@rdf:about"/>

    <xsl:function name="ac:label" as="xs:string">
        <xsl:param name="resource" as="element()"/>

        <xsl:for-each select="$resource">
            <xsl:choose>
                <!-- Prefer English labels -->
                <xsl:when test="skos:prefLabel[lang('en')]">
                    <xsl:sequence select="string(skos:prefLabel[lang('en')][1])"/>
                </xsl:when>
                <xsl:when test="foaf:name[lang('en')]">
                    <xsl:sequence select="string(foaf:name[lang('en')][1])"/>
                </xsl:when>
                <xsl:when test="rdfs:label[lang('en')]">
                    <xsl:sequence select="string(rdfs:label[lang('en')][1])"/>
                </xsl:when>
                <xsl:when test="dct:title[lang('en')]">
                    <xsl:sequence select="string(dct:title[lang('en')][1])"/>
                </xsl:when>
                <!-- Fallback to any language -->
                <xsl:when test="skos:prefLabel">
                    <xsl:sequence select="string(skos:prefLabel[1])"/>
                </xsl:when>
                <xsl:when test="foaf:name">
                    <xsl:sequence select="string(foaf:name[1])"/>
                </xsl:when>
                <xsl:when test="rdfs:label">
                    <xsl:sequence select="string(rdfs:label[1])"/>
                </xsl:when>
                <xsl:when test="dct:title">
                    <xsl:sequence select="string(dct:title[1])"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- Fallback: use last segment of rdf:about, or rdf:nodeID for blank nodes -->
                    <xsl:sequence select="if (@rdf:about) then tokenize(@rdf:about, '[/#]')[last()] else @rdf:nodeID"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>

</xsl:stylesheet>
