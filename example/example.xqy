(:
 : This module contains code to test
:)
xquery version "1.0-ml";

module namespace ex  = "http://marklogic.com/example";

declare option xdmp:mapping "false";

declare function ex:update-bar(
) as empty-sequence()
{
  let $uri := "/my/doc.xml"
  let $doc := fn:doc($uri)
  return (
    xdmp:node-replace($doc/doc/foo/text(), text {"baz"}),
	 xdmp:node-replace($doc/doc/updateDatetime/text(), text {fn:current-dateTime()}),
	 xdmp:document-add-collections($uri, "favorites"),
	 xdmp:document-add-permissions($uri, xdmp:permission("app-user", "insert"))
  )
};
