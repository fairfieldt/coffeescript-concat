# coffeescript-concat.coffee 
#
#  Copyright (C) 2010-2013 Tom Fairfield
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
	return classNames.concat(findExternClasses(file))

findExternClasses = (file) ->
	file = '\n' + file
	externRegex = /#=\s*extern\s+([A-Za-z_$-][A-Za-z0-9_$-.]*)/g
	classNames = []
	while (result = externRegex.exec(file)) != null
		classNames.push(result[1])
	return classNames

# Search through a file and find all dependencies,
# which is be done by finding all 'exends'
# statements.  Ignore those in comments
# also find the dependencies marked by #= require ClassName
#
findClassDependencies = (file) ->
	file = '\n' + file
	
	dependencyRegex = /\n[^#\n]*extends\s([A-Za-z_$-][A-Za-z0-9_$-.]*)/g
	
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

getFileNamesInDirsR = (dirs, filesFound, callback) ->
	if dirs.length > 0
		nextDir = dirs[dirs.length-1]
		fs.readdir nextDir, (err, files) ->
			directories = []
			if err
				throw err
			else
				for file in files
					filePath = nextDir.replace(/\/$/, '') + '/' + file
					stats = fs.statSync filePath
					if stats.isDirectory()
						directories.push filePath
					else if stats.isFile()
						filesFound.push filePath

				dirs.splice dirs.length-1, 1
				dirs = dirs.concat directories

				getFileNamesInDirsR dirs, filesFound, (innerFilesFound) ->
					callback innerFilesFound
	else
		callback filesFound

# Given a list of directories, find all files recursively. The callback gets
# one argument (filesFound) where filesFound is a list of all the files
# present in each directory and subdirectory (excluding '.' and '..').
#
getFileNamesInDirs = (dirs, callback) ->
	getFileNamesInDirsR dirs, [], callback

# Given a path to a directory and, optionally, a list of search directories
#, create a list of all files with the
# classes they contain and the classes those classes depend on.
#	
mapDependencies = (sourceFiles, searchDirectories, searchDirectoriesRecursive, callback) ->

	files = sourceFiles
	for dir in searchDirectories
		files = files.concat(path.join(dir, f) for f in fs.readdirSync(dir))

	getFileNamesInDirs searchDirectoriesRecursive, (filesFound) ->
		files = files.concat filesFound

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

		callback fileDefs

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
	sourceFileDefs = sourceFileDefs.concat(fileDefs)

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
	
# Given a list of source files,
# a list of directories to look into for source files,
# another list of directories to look into for source files recursevily
# and a relative filename to output,
# resolve the dependencies and put all classes in one file
concatenate = (sourceFiles, includeDirectories, includeDirectoriesRecursive, outputFile) ->
	mapDependencies sourceFiles, includeDirectories, includeDirectoriesRecursive, (deps) ->

		output = concatFiles(sourceFiles, deps)
		output = removeDirectives(output)
		if outputFile
			fs.writeFile(outputFile, output)
		else
			util.puts(output)


options = require('optimist').
usage("""Usage: coffeescript-concat [-I .] [-R .] [-o outputfile.coffee] a.coffee b.coffee
If no output file is specified, the resulting source will sent to stdout
""").
describe('h', 'display this help').
alias('h','help').
describe('I', 'directory to search for files').
alias('I', 'include-dir').
describe('R', 'directory to search for files recursively').
alias('R', 'include-dir-recursive').
describe('o', 'output file name').
alias('o', 'output-file')

argv = options.argv
includeDirectories = if typeof argv.I is 'string' then [argv.I] else argv.I or []
includeDirectoriesRecursive = if typeof argv.R is 'string' then [argv.R] else argv.R or []
sourceFiles = if typeof argv._ is 'string' then [argv._] else argv._
if argv.help || (includeDirectories.length==0 && includeDirectoriesRecursive.length==0 && sourceFiles.length==0)
	options.showHelp()

concatenate(sourceFiles, includeDirectories, includeDirectoriesRecursive, argv.o)