xquery version "1.0-ml";

module namespace dw = "http://marklogic.com/roxy/data-works";

import module namespace sec = "http://marklogic.com/xdmp/security"
  at "/MarkLogic/security.xqy";
import module namespace functx = "http://www.functx.com"
  at "/MarkLogic/functx/functx-1.0-nodoc-2007-01.xqy";
import module namespace test = "http://marklogic.com/roxy/test-helper"
  at "/test/test-helper.xqy";
import module namespace util = "http://marklogic.com/xdmp/utilities" 
   at "/MarkLogic/utilities.xqy";

declare namespace t = "http://marklogic.com/roxy/test";
declare namespace xsl = "http://www.w3.org/1999/XSL/Transform";

declare option xdmp:mapping "false";

declare variable $URI-DIRECTORY-DELIMITER := "--";
declare variable $METADATA-EXTENSION := "---metadata.xml";
declare variable $BEFORE-DIRECTORY := "before";
declare variable $AFTER-DIRECTORY := "after";
declare variable $ROXY-BOOM := "ROXY-BOOM";

(:
Data format/layout:
- WARNING: This does not work with a filesystem DB (DB ID 0).
- Use -- in the file name to denote a / in the corresponding URI (do not include leading "--").
- Optionally, put your permissions and collections in a sidecar file with the same file name as the associated document, but ending with $METADATA-EXTENSION.
sample metadata file:
<metadata>
  <permissions>
    <permission>
      <role-name>app-role</role-name>
      <capability>read</capability>
    </permission>
    <permission>
      <role-name>app-role</role-name>
      <capability>update</capability>
    </permission>
  </permissions>
  <collections>
    <collection>favorites</collection>
  </collections>
</metadata>

How to load data:
Put your test data in the suite test-data/<test-name>/<$BEFORE-DIRECTORY>/ directory.
If there is no metadata file, the document will be inserted with default collections and permissions of the user executing the tests.

How to compare data:
Put your expected result data in the suite test-data/<test-name>/<$AFTER-DIRECTORY>/ directory.
If there is no metadata file, there will be no check of collections or permissions.  If the metadata file exists, but does not contain both sections (collections and permissions), only existing sections will be checked.
:)


(:~
 : Load data from $BEFORE-DIRECTORY directory into the DB.
 :
 : @return The empty sequence
 :)
declare function dw:load-data(
) as empty-sequence()
{
  for $module-doc-uri in dw:get-test-data($BEFORE-DIRECTORY)
  let $uri := dw:get-content-uri-from-modules-uri($module-doc-uri)
  let $doc := test:get-modules-file($module-doc-uri)
  let $metadata := dw:get-metadata($module-doc-uri)
  let $permissions := dw:get-permissions($metadata)
  let $collections := dw:get-collections($metadata)
  return xdmp:document-insert(
    $uri,
    $doc,
    $permissions,
    $collections
  )
};

(:~
 : Remove data corresponding to the $BEFORE-DIRECTORY and $AFTER-DIRECTORY directories from the DB.
 :
 : @return The empty sequence
 :)
declare function dw:remove-data(
) as empty-sequence()
{
  for $module-doc-uri in fn:distinct-values((dw:get-test-data($BEFORE-DIRECTORY), dw:get-test-data($AFTER-DIRECTORY)))
  let $uri := dw:get-content-uri-from-modules-uri($module-doc-uri)
  return
    if (fn:doc-available($uri))
    then xdmp:document-delete($uri)
    else ()
};

(:~
 : Compare documents in $AFTER-DIRECTORY directory (including permissions/collections) to what's in the database.
 :
 : @return Test assertions
 :)
declare function dw:compare-data(
) as element(t:result)*
{
  dw:compare-data(())
};

(:~
 : Compare (ignoring elements specified by $elements-to-ignore) files in $AFTER-DIRECTORY directory (including permissions/collections) to documents in the database.
 :
 : @param $elements-to-ignore Elements to ignore in the comparison
 : @return Test assertions
 :)
declare function dw:compare-data(
  $elements-to-ignore as xs:QName*
) as element(t:result)*
{
  for $module-doc-uri in dw:get-test-data($AFTER-DIRECTORY)
  let $uri := dw:get-content-uri-from-modules-uri($module-doc-uri)
  let $expected-doc := test:get-modules-file($module-doc-uri)
  let $metadata := dw:get-metadata($module-doc-uri)
  let $expected-permissions := dw:get-permissions($metadata)
  let $expected-collections := dw:get-collections($metadata)
  let $actual-doc := fn:doc($uri)
  let $actual-permissions := xdmp:document-get-permissions($uri)
  let $actual-collections := xdmp:document-get-collections($uri)
  return (
    test:assert-equal(
      dw:strip-uncomparables($expected-doc, $elements-to-ignore),
      dw:strip-uncomparables($actual-doc, $elements-to-ignore)(:,
      "Content not equal for " || $expected-doc/fn:base-uri() || " and " || $actual-doc/fn:base-uri():)
    ),
    if (dw:permissions-exist($metadata))
    then (: permissions exist on the metadata doc... check them :)
      test:assert-same-values(
        (: assert-same-values fails on <sec:permission> due to the order by (which implicitly does fn:data() on the element... related to the fact that there is a schema for it :)
        $expected-permissions/fn:string(),
        $actual-permissions/fn:string()(:,
        "Permissions not equal for " || $expected-doc/fn:base-uri() || " and " || $actual-doc/fn:base-uri():)
      )
    else (),
    if (dw:collections-exist($metadata))
    then (: collections exist on the metadata doc... check them :)
      test:assert-same-values(
        $expected-collections,
        $actual-collections(:,
        "Collections not equal for " || $expected-doc/fn:base-uri() || " and " || $actual-doc/fn:base-uri():)
      )
    else ()
  )
};

(:~
 : Return modules URIs of test data documents (excluding metadata).
 :
 : @param $which Where to get test data ($BEFORE-DIRECTORY or $AFTER-DIRECTORY)
 : @return URIs of test data documents
 :)
declare function dw:get-test-data(
  $which as xs:string
) as xs:string*
{
  if ($which ne $BEFORE-DIRECTORY and $which ne $AFTER-DIRECTORY)
  then fn:error(xs:QName("INVALIDPARAM"), "Must specify either """ || $BEFORE-DIRECTORY || """ or """ || $AFTER-DIRECTORY || """", $which)
  else
    xdmp:invoke-function(
      function() {
        cts:uris(
          (),
          (),
          cts:directory-query(dw:get-test-data-path() || $which || "/")
        )[fn:not(fn:ends-with(., $METADATA-EXTENSION))]
      },
      <options xmlns="xdmp:eval">
        <database>{xdmp:modules-database()}</database>
      </options>
    )
};

(:~
 : Return content database URI corresponding to the modules database URI.
 :
 : @param $modules-uri The modules database URI of the document
 : @return The content database URI of the document
 :)
declare function dw:get-content-uri-from-modules-uri(
  $modules-uri as xs:string
) as xs:string
{
  "/" || fn:replace(util:basename($modules-uri), $URI-DIRECTORY-DELIMITER, "/")
};

(:~
 : Return a copy of $node without any whitespace.
 :
 : @param $node The node to copy
 : @return A copy of $node without any whitespace
 :)
declare function dw:unindent-xml(
  $node as node()
) as document-node()
{
  dw:strip-uncomparables($node, ())
};

(:~
 : Return XSLT templates to drop the elements specified by $elements-to-drop.
 :
 : @param $elements-to-drop The elements for which to construct drop templates
 : @return XSLT templates
 :)
declare function dw:construct-drop-templates(
  $elements-to-drop as xs:QName*
) as element(xsl:template)*
{
  for $element-to-drop in $elements-to-drop
  let $ns := fn:namespace-uri-from-QName($element-to-drop)
  let $local-name := fn:local-name-from-QName($element-to-drop)
  return (
    element {xs:QName("xsl:template")} {
      if ($ns ne "")
      then (
        attribute {"xmlns:ns"} {$ns},
        attribute {"match"} {"ns:" || $local-name}
      )
      else attribute {"match"} {$local-name}
    }
  )
};

(:~
 : Return a copy of $node without $elements-to-drop and without any whitespace.
 :
 : @param $node The node to copy
 : @param $elements-to-drop Elements to exclude from the copy
 : @return A copy of $node without $elements-to-drop and without any whitespace
 :)
declare function dw:strip-uncomparables(
  $node as node(),
  $elements-to-drop as xs:QName*
) as document-node()
{
  xdmp:xslt-eval(
    <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
      <xsl:output method="xml" encoding="UTF-8" indent="no"/>
      <xsl:strip-space elements="*"/>
      
      <!-- identity template -->
      <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
      </xsl:template>

      <!-- additional elements to drop -->
      {dw:construct-drop-templates($elements-to-drop)}

    </xsl:stylesheet>
  ,
  $node)
};

(:~
 : Return the module database URI directory of the test data.
 :
 : @return The module database URI directory of the test data
 :)
declare function dw:get-test-data-path(
) as xs:string
{
  let $module := dw:get-caller()
  return util:basepath($module) || "/test-data/" || functx:substring-before-last(util:basename($module), ".") || "/"
};

(:~
 : Return the caller of this function (copied from helper:get-caller, but can't use that version because that's another frame on the stack).
 :
 : @return the caller of this function
 :)
declare function dw:get-caller()
  as xs:string
{
  try { fn:error((), $ROXY-BOOM) }
  catch ($ex) {
    if ($ex/error:code ne $ROXY-BOOM)
    then xdmp:rethrow()
    else (
      let $uri-list := $ex/error:stack/error:frame/error:uri/fn:string()
      let $this := $uri-list[1]
      return (($uri-list[. ne $this])[1], 'no file')[1])
  }
};

(:~
 : Return the metadata document associated with the test data document at $module-doc-uri.
 :
 : @return The metadata document
 :)
declare function dw:get-metadata(
  $module-doc-uri as xs:string
) as document-node()?
{
  test:get-modules-file(functx:substring-before-last($module-doc-uri, ".") || $METADATA-EXTENSION)
};

(:~
 : Return the collections from the metadata document.
 :
 : @return A sequence of collections
 :)
declare function dw:get-collections(
  $metadata as document-node()?
) as xs:string*
{
  dw:get-collections-element($metadata)/collection/fn:string()
};

(:~
 : Return the permissions from the metadata document.
 :
 : @return A sequence of permissions
 :)
declare function dw:get-permissions(
  $metadata as document-node()?
) as element(sec:permission)*
{
  for $permission in dw:get-permissions-element($metadata)/permission
    let $capability := $permission/capability/fn:string()
    let $role-id := xdmp:invoke-function(
      function() {
        sec:get-role-ids($permission/role-name/fn:string())
      },
      <options xmlns="xdmp:eval">
        <database>{xdmp:security-database()}</database>
      </options>
    )
    (: $role-id is the sec:role-id element :)
    return
      <sec:permission xmlns:sec="http://marklogic.com/xdmp/security">
        <sec:capability>{$capability}</sec:capability>
        {$role-id}
      </sec:permission>
};

(:~
 : Return whether collections are specified by the metadata document.
 :
 : @return Whether collections are specified by the metadata document
 :)
declare function dw:collections-exist(
  $metadata as document-node()?
) as xs:boolean
{
  fn:exists(dw:get-collections-element($metadata))
};

(:~
 : Return whether permissions are specified by the metadata document.
 :
 : @return Whether permissions are specified by the metadata document
 :)
declare function dw:permissions-exist(
  $metadata as document-node()?
) as xs:boolean
{
  fn:exists(dw:get-permissions-element($metadata))
};

(:~
 : Return the collections from the metadata document.
 :
 : @return The collections element
 :)
declare function dw:get-collections-element(
  $metadata as document-node()?
) as element(collections)?
{
  $metadata/metadata/collections
};

(:~
 : Return the permissions from the metadata document.
 :
 : @return The permissions element
 :)
declare function dw:get-permissions-element(
  $metadata as document-node()?
) as element(permissions)?
{
  $metadata/metadata/permissions
};
