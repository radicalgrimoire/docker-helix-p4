#!/usr/bin/python3.4
#
# CaseCheckTrigger.py
#
#
# Copyright (c) 2008, Perforce Software, Inc.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1.  Redistributions of source code must retain the above copyright
#	 notice, this list of conditions and the following disclaimer.
# 
# 2.  Redistributions in binary form must reproduce the above copyright
#	  notice, this list of conditions and the following disclaimer in the
#	 documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL PERFORCE SOFTWARE, INC. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# $Id: //guest/sven_erik_knop/P4Pythonlib/triggers/CheckCaseTrigger.py#20 $
#
# Example Usage:
#  CheckCaseTrigger change-submit //... "python CheckCaseTrigger.py %changelist% myuser=%user%"
#
# NOTE: 'mysuser' is only used to exclude the 'git-fusion-user' from this check.
#       Even if you are not using Git Fusion we recomend setting the trigger up this
#       way just in case you install Git Fusion in future.
#
# Sample output:
#
# Submit validation failed -- fix problems then use 'p4 submit -c 1234'.
#  'CheckCaseTrigger' validation failed:
#
#	Your submission has been rejected because the following files
#	are inconsistent in their use of case with respect to existing
#	directories
#
#	Your file:         '//depot/dir/test'
#	existing file/dir: '//depot/DIR'
#
#  Note: This trigger requires P4Triggers.py and the P4Python API.
#
# 
from __future__ import print_function

import P4
import P4Triggers
import sys

class CheckCaseTrigger( P4Triggers.P4Trigger ):
	"""CaseCheckTrigger is a subclass of P4Trigger. Use this trigger to ensure
	   that your depot does not contain two filenames or directories that only
	   differ in case.
	   Having files with different case spelling will cause problems in mixed 
	   environments where both case-insensitive clients like Windows and case-
	   sensitive clients like UNIX access the same server.
	"""
	
	def __init__( self, maxErrors, **kargs):
		kargs['charset'] = 'none'
		kargs['api_level'] = 71
		
		fileFilter = None
		if 'filefilter' in kargs:
			fileFilter = kargs['filefilter']
			del kargs['filefilter']
		
		P4Triggers.P4Trigger.__init__(self, **kargs)
	  
		# need to reset the args in case a p4config file overwrote them
		for (k,v) in kargs.items():
			if k != "log":
				setattr( self.p4, k, v)
		
		self.map = None
		if fileFilter:
			try:
				with open(fileFilter) as f:
					self.map = P4.Map()
					for line in f:
						self.map.insert(line.strip())
			except IOError:
				print >> self.log, "Could not open filter file %s" % fileFilter
		
		self.maxErrors = maxErrors
		self.depotCache = {}
		self.dirCache = {}
		self.fileCache = {}
	  
	def setUp( self ):
		info = self.p4.run_info()[0]
		if "unicode" in info and info["unicode"] == "enabled":
			self.p4.charset = "utf8"
		self.p4.exception_level = 1 # ignore WARNINGS like "no such file"
		self.p4.prog = "CheckCaseTrigger"
	  

		self.USER_MESSAGE="""
	
	Your submission has been rejected because the following files
	are inconsistent in their use of case with respect to existing
	directories
	
		"""
	
		self.BADFILE_FORMAT="""
	Your file:         '%s'
	existing file/dir: '%s'
		"""
	
	def validate( self ):
		"""Here the fun begins. This method overrides P4Trigger.validate()"""
		badlist = {}
		files = self.change.files
	  
		self.filterRenames(files)
	  
		for file in files:
			action = file.revisions[0].action
			if self.map and self.map.includes(file.depotFile):
				continue
			if action not in ("add", "branch", "move/add"): 
				continue
		
			mismatch = self.findMismatch( file.depotFile )
			if mismatch:
				badlist[ file.depotFile ] = mismatch
		  
	 	 # end for
	  
		if len( badlist ) > 0:
			self.report( badlist ) 
	
		return len(badlist) == 0
	
	# Method canonical 
	# IN:  string, utf8 compatible
	# OUT: unicode string, all lower case
	def canonical( self, aString ):
		if self.p4.charset == "utf8":
			return unicode( aString, "utf8").lower()
		else:
			return aString.lower()

	# Method filterRenames:
	# Removes pairs of files that only differ in case
	# where one action is branch, and the other delete
	def filterRenames( self, files ):
		branches = [ x for x in files if x.revisions[0].action == 'branch' ]
		deletes = [ x.depotFile.lower() for x in files if x.revisions[0].action == 'delete' ]
		
		for f in branches:
			if f.depotFile.lower() in deletes:
				files.remove(f)

	# This method returns either a depot or directory that differs from 
	# the supplied path only in case, or None if no mismatch is found
	def findMismatch( self, path ):
		path = path[2:] # cut the // at the beginning of the depot off
		dirs = path.split('/')
		depot = dirs.pop(0)
		file = dirs.pop()
		
		depotMismatch = self.findDepotMismatch( depot )
		if ( depotMismatch ):
			return depotMismatch
		
		oldDirs = dirs[:]
		dirMismatch = self.findDirMismatch( '//' + depot, dirs )
		if ( dirMismatch ):
			return dirMismatch
		
		fileMismatch = self.findFileMismatch( depot, oldDirs, file )
		if ( fileMismatch ): 
		  return fileMismatch
		
		return None

	# This method looks for a depot mismatch
	# It caches the depots as it found them
	# IN: depot name (as provided by the change list
	# OUT: None if (no mismatch found) else (stored depot name)

	def findDepotMismatch( self, depot ):
		canonicalDepot = self.canonical( depot )
	
		# if the depot is in the cache, the cached version is authorative
	
		if canonicalDepot in self.depotCache:
			if self.depotCache[ canonicalDepot ] == depot:
				return None
			else:
				return '//' + self.depotCache[ canonicalDepot ]
	
		# depot not found in cache. Populate the cache
	
		mismatch = None
		for d in self.p4.run_depots():
			dname = d[ "name" ]
			cd = self.canonical( dname )
			self.depotCache[ cd ] = dname
			if canonicalDepot == cd and depot != dname:
				mismatch = '//' + dname
	
		return mismatch
	# end findDepotMismatch

	# Look for matching or mismatching directories
	# Recursive algorithm, descending down the directory paths
	# Caching directories as we find them
	# 
	
	def findDirMismatch( self, top, dirs ):
		if len(dirs) == 0:
			return None
		
		aDir = dirs.pop(0)
		path = top + '/' + aDir
		cpath = self.canonical( path )
		
		if cpath in self.dirCache :
			# negative lookups are cached with the value set to False
			if ( self.dirCache[ cpath ] == path ) or ( self.dirCache[ cpath ] == False ) :
			   return self.findDirMismatch( path, dirs )
			else:
				# it is a mismatch, either with a previously stored name, or, worse 
				# with a previous file in the same change list
			
				return self.dirCache [ cpath ]
			# end if
		# end if
		
		# so, it is not in the cache. Let's populate the cache and check 
		# while we are at it
		
		mismatch = None
		for d in self.p4.run_dirs( top + "/*"):
			d = d[ "dir" ]	# result is in tagged mode, single entry "dir"=>directory name
			cd = self.canonical ( d )
			self.dirCache[ cd ] = d
			
			if cd == cpath:
				# we found the dir entry. Is it the right case?
				
				if d == path:
					# so far so good, lets step one directory level down
					
					mismatch = self.findDirMismatch( path, dirs )
				else:
					# oh-ho, we found a mismatch
					mismatch = d
				# end if d == path
			# end if cd == cpath
		# end for
		
		if not mismatch:
			# enter as a negative match
			self.dirCache [ cpath ] = False
			
		return mismatch
		
	def findFileMismatch( self, depot, dirs, file ):
		base = '//' + depot + '/'
		if ( len(dirs) > 0 ):
			base += '/'.join(dirs) 
			base += '/'
		
		name = base + file
		cname = self.canonical( name )
		if cname in self.fileCache:
			if ( self.fileCache[ cname ] == name ):
				return None # all is well, but cannot happen, add would fail
			else:
				return self.fileCache[ cname ]
		
		# so the file is not in the cache. Let's load the cache
		for f in self.p4.run_files(base + "*"):
			if "delete" not in f[ "action"]:
				f = f[ "depotFile" ]
				cf = self.canonical( f )
				self.fileCache[ cf ] = f
				if( cf == cname and f != name ):
					return f
		
		# so it is not in the file cache
		self.fileCache[ cname ] = name
		return None
		
	def report( self, badfiles ):
		msg = self.USER_MESSAGE
		for ( n, (file, mismatch) ) in enumerate( badfiles.items() ):
			if n >= self.maxErrors:
		  		break
			msg += self.BADFILE_FORMAT % ( file, mismatch )
		  
		self.message( msg )

# main routine.
# If called from the command line, go in here

if __name__ == "__main__":
	kargs = {}
	try:
		for arg in sys.argv[2:]:
			(key,value) = arg.split("=", 1)
			kargs[key] = value
	except Exception as e :
		print("Error, expecting arguments in form key=value. Bailing out ...")
		print(e)
		sys.exit(0)

	# Example of how to exclude the 'git-fusion-user'
	# Note: Need to remove 'mysuser' after test as it's not a valid P4 argument.
	if 'myuser' in kargs: 
		if kargs['myuser'] == 'git-fusion-user':
			sys.exit(0)
		else:
			del kargs['myuser']

	ct = CheckCaseTrigger( 10 , **kargs)
	sys.exit( ct.parseChange( sys.argv[1] ) )
