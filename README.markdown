**coffeescript-concat** is a utility that preprocesses and concatenates CoffeeScript source files.

It makes it easy to keep your CoffeeScript code in separate units and still run them easily.  You can keep your source logically separated without the frustration of putting it all together to run or embed in a web page.  Additionally, coffeescript-concat will give you a single sourcefile that will easily compile to a single Javascript file.

**coffeescript-concat performs 3 operations:**

* Automatically puts parent classes in an inheritance chain in the correct order

* Allows you to specify that a class from another file needs to be included before another file.
    When a `#= require Classname` directive is encountered, coffeescript-concat will find the file containing that class, preprocess it, and put it above the including class.
    
* Allows you to specifiy that a file needs to be included before another file.
    When a `#= require <FileName>` or `#=require <FileName.coffee>` directive is encountered, coffeescript-concat will find the file, preprocess it, and put it above the including class. 
    
How does coffeescript-concat find the classes and files?  By specifying include directories, you can tell coffeescript where to look.  If it can't find the needed file in any of the include directories, it will let you know.

**Using coffeescript-concat:**

coffeescript concat requires a [node.js](http://nodejs.org) installation, [CoffeeScript](http://jashkenas.github.com/coffee-script/), and [underscore.js](http://documentcloud.github.com/underscore/).

Use coffeescript-concat like this:

    coffee coffeescript-concat.coffee -I /my/include/directory -I includeDir2 A.coffee B.coffee > output.coffee
    
This will preprocess and concatenate This.coffee, That.coffee, and TheOther.coffee along with any classes they require and output the resulting code into output.coffee.  coffeescript-concat prints the output to stdout so that you can easily write it to a file or pipe it to another utility for further processing.  
