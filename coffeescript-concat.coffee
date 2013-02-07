# coffeescript-concat.coffee 
#
#  Copyright (C) 2010-2011 Tom Fairfield
#
#  This software is provided 'as-is', without any express or implied
#  warranty.  In no event will the authors be held liable for any damages
#  arising from the use of this software.
#
#  Permission is granted to anyone to use this software for any purpose,
#  including commercial applications, and to alter it and redistribute it
#  freely, subject to the following restrictions:
#
#  1. The origin of this software must not be misrepresented; you must not
#     claim that you wrote the original software. If you use this software
#     in a product, an acknowledgment in the product documentation would be
#     appreciated but is not required.
#  2. Altered source versions must be plainly marked as such, and must not be
#     misrepresented as being the original software.
#  3. This notice may not be removed or altered from any source distribution.
#
# Tom Fairfield <fairfield@cs.xu.edu>
#

util = require('util')
fs = require('fs')
path = require('path')
_ = require('underscore')

# Search through a file and find all class definitions,
# ignoring those in comments
#
findClasses = (file) ->
	file = '\n' + file
	classRegex = /\n[^#\n]*class\s([A-Za-z_$-][A-Za-z0-9_$-]*)/g
	
	classNames = []
	while (result = classRegex.exec(file)) != null
		classNames.push(result[1])
	return classNames

# Search through a file and find all dependencies,
# which is be done by finding all 'exends'
# statements.  Ignore those in comments
# also find the dependencies marked by #= require ClassName
#
findClassDependencies = (file) ->
	file = '\n' + file
	
	dependencyRegex = /\n[^#\n]*extends\s([A-Za-z_$-][A-Za-z0-9_$-]*)/g
	
	dependencies = []
	while (result = dependencyRegex.exec(file)) != null
		dependencies.push(result[1])
		
	file = file.replace(dependencyRegex, '')
		
	classDirectiveRegex = /#=\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-]*)/g
	while (result = classDirectiveRegex.exec(file)) != null
		dependencies.push(result[1])
		
	return dependencies

# Search through a file, given as a string and find the dependencies marked by
# #= require <FileName>
#
#
findFileDependencies = (file) ->
	file = '\n' + file
	
	dependencies = []
	fileDirectiveRegex = /#=\s*require\s+<([A-Za-z_$-][A-Za-z0-9_$-.]*)>/g
	
	while (result = fileDirectiveRegex.exec(file)) != null
		dependencies.push(result[1])
		
	return dependencies
	
# Given a path to a directory and, optionally, a list of search directories
#, create a list of all files with the
# classes they contain and the classes those classes depend on.
#	
mapDependencies = (sourceFiles, searchDirectories) ->
	files = sourceFiles
	for dir in searchDirectories
		files = files.concat(path.join(dir, f) for f in fs.readdirSync(dir))

	fileDefs = []
	for file in files when /\.coffee$/.test(file)
		contents = fs.readFileSync(file).toString()
		classes = findClasses(contents)
		dependencies = findClassDependencies(contents)
		fileDependencies = findFileDependencies(contents)
		#filter out the dependencies in the same file.
		dependencies = _.select(dependencies, (d) -> _.indexOf(classes, d) == -1)
		
		fileDef = {name: file, classes: classes, dependencies: dependencies, fileDependencies: fileDependencies, contents: contents}
		fileDefs.push(fileDef)
		
	return fileDefs

# Given a list of files and their class/dependency information,
# traverse the list and put them in an order that satisfies dependencies. 
# Walk through the list, taking each file and examining it for dependencies.
# If it doesn't have any it's fit to go on the list.  If it does, find the file(s)
# that contain the classes dependencies.  These must go first in the hierarchy.
#	
concatFiles = (sourceFiles, fileDefs) ->	
	usedFiles = []
	allFileDefs = fileDefs.slice(0)
	sourceFileDefs = (fd for fd in fileDefs when fd.name in sourceFiles)

	# Given a class name, find the file that contains that
	# class definition.  If it doesn't exist or we don't know
	# about it, return null
	findFileDefByClass = (className) ->
		for fileDef in allFileDefs
			for c in fileDef.classes
				if c == className
					return fileDef
		return null
	
	# Given a filename, find the file definition that
	# corresponds to it.  If the file isn't found,
	# return null
	findFileDefByName = (fileName) ->
		for fileDef in allFileDefs
			temp = fileDef.name.split('/')
			name = temp[temp.length-1].split('.')[0]
			if fileName == name
				return fileDef
		return null
	
	# recursively resolve the dependencies of a file.  If it 
	# has no dependencies, return that file in an array.  Otherwise,
	# find the files with the needed classes and resolve their dependencies
	#
	resolveDependencies = (fileDef) ->
		dependenciesStack = []
		if _.indexOf(usedFiles, fileDef.name) != -1
			return null
		else if fileDef.dependencies.length == 0 and fileDef.fileDependencies.length == 0
			dependenciesStack.push(fileDef)
			usedFiles.push(fileDef.name)
		else
			dependenciesStack = []
			for dependency in fileDef.dependencies
				depFileDef = findFileDefByClass(dependency)
				if depFileDef == null
					console.error("Error: couldn't find needed class: " + dependency)
				else
					nextStack = resolveDependencies(depFileDef)
					dependenciesStack = dependenciesStack.concat(if nextStack != null then nextStack else [])
				
			for neededFile in fileDef.fileDependencies
				neededFileName = neededFile.split('.')[0]
				
				neededFileDef = findFileDefByName(neededFileName)
				if neededFileDef == null
					console.error("Error: couldn't find needed file: " + neededFileName)
				else
					nextStack = resolveDependencies(neededFileDef)
					dependenciesStack = dependenciesStack.concat(if nextStack != null then nextStack else [])

						
			if _.indexOf(usedFiles, fileDef.name) == -1
					dependenciesStack.push(fileDef)
					usedFiles.push(fileDef.name)
					
				

		return dependenciesStack
			
	fileDefStack = []
	while sourceFileDefs.length > 0
		nextFileDef = sourceFileDefs.pop()
		resolvedDef = resolveDependencies(nextFileDef)
		if resolvedDef
			fileDefStack = fileDefStack.concat(resolvedDef)

#	for f in fileDefStack
#		console.error(f.name)
	output = ''
	for nextFileDef in fileDefStack
		output += nextFileDef.contents + '\n'

	return output
	
# remove all #= require directives from the
# source file.
removeDirectives = (file) ->
	fileDirectiveRegex = /#=\s*require\s+<([A-Za-z_$-][A-Za-z0-9_$-.]*)>/g
	classDirectiveRegex = /#=\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-]*)/g
	file = file.replace(fileDirectiveRegex, '')
	file = file.replace(classDirectiveRegex, '')
	
	return file
	
# Given a source directory, a relative filename to output
# to, and optionally a list of class names to ignore, 
# resolve the dependencies and put all classes in one file
#
concatenate = (sourceFiles, includeDirectories, outputFile) ->
	deps = mapDependencies(sourceFiles, includeDirectories)

	output = concatFiles(sourceFiles, deps)
	output = removeDirectives(output)
	if outputFile
		fs.writeFile(outputFile, output)
	else
		util.puts(output)


argv = require('optimist').
usage("""Usage: coffeescript-concat [-I .] [-o outputfile.coffee] a.coffee b.coffee
If no output file is specified, the resulting source will sent to stdout
""").
describe('I', 'directory to search for files').
alias('I', 'include-dir').
describe('o', 'output file name').
alias('o', 'output-file').
argv

includeDirectories = argv.I or []
sourceFiles = argv._

concatenate(sourceFiles, includeDirectories, argv.o)
