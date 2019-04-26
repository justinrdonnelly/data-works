(:
 : Test info:
 : Demonstrate how to use Data Works
 :)
xquery version "1.0-ml";
import module namespace dw = "http://marklogic.com/roxy/data-works" at "/test/data-works.xqy";
dw:load-data()
; (: transaction separator :)

xquery version "1.0-ml";
import module namespace ex  = "http://marklogic.com/example" at "/example.xqy";
ex:update-bar()
; (: transaction separator :)

(: test results :)
xquery version "1.0-ml";
import module namespace dw = "http://marklogic.com/roxy/data-works" at "/test/data-works.xqy";
dw:compare-data(xs:QName("updateDatetime")), (: ignore the updateDatetime for comparison :)
dw:remove-data()
