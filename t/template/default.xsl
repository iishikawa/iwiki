<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns         = "http://example.org/dummy#"
  xmlns:xsl     = "http://www.w3.org/1999/XSL/Transform"
  xmlns:ex      = "http://example.org/ns#"
  xmlns:h       = "http://www.w3.org/1999/xhtml"
  xmlns:rdf     = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dcterms = "http://purl.org/dc/terms/"
  exclude-result-prefixes="ex h rdf dcterms">

  <xsl:output
    method="xml"
    version="1.0"
    media-type="text/html"
    encoding="UTF-8"
    doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
    omit-xml-declaration="no"
    indent="no"/>

  <xsl:namespace-alias stylesheet-prefix="#default" result-prefix="h"/>

  <xsl:template match="/rdf:RDF/rdf:Description[1]">
    <html>
      <head>
        <title><xsl:value-of select="dcterms:title"/></title>
      </head>
      <body>
        <h1><xsl:value-of select="dcterms:title"/></h1>
        <xsl:apply-templates select="h:body/*" mode="copy"/>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="h:*" priority="1.0" mode="copy">
    <xsl:element name="{local-name()}" namespace="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates select="@*|node()" mode="copy"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="*" priority="0.9" mode="copy">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="copy"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*|text()|comment()" priority="0.3" mode="copy">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="copy"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*|node()" priority="-0.5" mode="copy"/>

</xsl:stylesheet>
