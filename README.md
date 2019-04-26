# Data Works

### Introduction
Data Works is a supplement to [marklogic-unit-test](https://github.com/marklogic-community/marklogic-unit-test).  It makes it easier to stage test data, compare expected against actual, and clean up test data.  I often see people using the suite setup (```suite-setup.xqy```) to insert test data for every test.  When a new test is added, the suite setup (and often suite teardown) is updated.  The philosophy behind data works is that suite setup should only be for setup related to the suite as a whole, not individual tests.

### Loading Data
Data Works makes it easy to load data for a test by using directory and filename conventions.  Put test data in the ```before``` directory (```suites/<suite name>/test-data/<test name>/before/```).  Name files using ```--``` to represent URI directory ```/```, but without a leading ```--``` (a leading ```/``` is assumed).  If you prefer a different delimiter, change the declared variable ```$URI-DIRECTORY-DELIMITER``` in ```data-works.xqy```.  Example test data file path: ```suites/sample-suite/test-data/test-1/before/example--doc.xml```
By default, test data is inserted with the default permissions of the user running the tests and no collections.  This behavior can be overridden by the addition of a metadata file.  Each ```<permission>``` represents a permission on the associated test data document and each ```<collection>``` represents a collection on the associated test data document.  The metadata file goes in the same directory as the associated test data file, and is named the same, except that it ends with ```---metadata.xml```.  If you prefer a different extension, change the declared variable ```$URI-DIRECTORY-DELIMITER``` in ```data-works.xqy```.  Example test metadata file path: ```suites/sample-suite/test-data/test-1/before/example--doc---metadata.xml```
Example metadata file:
```xml
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
```
To load the data from these locations on your filesystem, in your test, import ```data-works.xqy``` and run ```dw:load-data```.  Be sure to do this in a separate transaction that completes before you need to access the data.

### Comparing Data
After executing code that modifies data, you often want to check the contents of the database to confirm it is as expected.  Data Works makes this easy.  Similar to lading test data, put expected data in the ```after``` directory (```suites/<suite name>/test-data/<test name>/after/```).  The same file naming convention is used.  If you need to test document permissions or collections, use a metadata file similar to the one used for loading test data.  There is a subtle difference in the way the metadata document is used for comparing than loading.  When loading, including an empty ```<permissions>``` element has the same meaning as not having a ```<permissions>``` element.  When comparing, these have different meanings.  An empty ```<permissions>``` element means there should be no permissions on the document.  Not having a ```<permissions>``` element means permissions are not specified, and won't be checked.  The same logic applies to collections.  To compare data, in your test, import ```data-works.xqy``` and run ```dw:compare-data```.  The function returns assertions, so you should return the results along with any other assertions in your test.  Be sure to do this in a separate transaction that begins after your test has made any modifications to the data.  In some cases there may be portions of a document to exclude from comparison.  Common examples are timestamps and UUIDs.  In these situations, pass a sequence of QNames to ```dw:compare-data```.  These elements will be dropped from the XML documents (via an XSLT transform) prior to comparison.  The current implementation uses the same QNames for all comparisons.  Excluding different elements from different documents is not currently supported.  Excluding portions of JSON documents from comparison is also not supported.  PRs welcome!

### Removing Data
It's generally a good idea to clean up your test data after your test has executed to reduce the likelihood if impacting other tests.  Data Works does this with the ```dw:remove-data``` function.  Just like other uses, import ```data-works.xqy``` and run ```dw:remove-data```.  Unlike other uses, you should be able to run this in the same transaction as ```dw:compare-data```.  This will remove any documents from the ```before``` or ```after``` directories.  It has no knowledge of any other documents that were created by the test and does not remove them.

### Using Data Works
Add ```data-works.xqy``` to the equivalent path of marklogic-unit-test, but in your project (```src/test/ml-modules/root/test/```).  Take a look at the example to see Data Works in action (note that ```example.xqy``` (the code to test), ```test.xqy``` (the code doing the testing), and the ```test-data``` directory are all in the example directory; obviously that's not realistic).

Use Data Works as you see fit.  If you need 1000 documents that are almost identical, it may be easier to generate that test data in a loop than create 1000 test data documents for use with Data Works.

### Other restrictions:
- Data Works does not support a filesystem database (database ID of 0).
- Data Works does not support JSON for the metadata file.
