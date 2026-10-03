#
# P4Triggers.py
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
# $Id: //guest/robert_cowham/perforce/utils/python/triggers/P4Triggers.py#1 $
# 
# 
# # Base class for all Python based P4 triggers
#

from __future__ import print_function

import P4
from datetime import datetime
import sys

class P4Change:
	"""Encapsulates a Perforce change. Basically a pretty wrapping around p4.run_describe()"""
	def __init__( self, desc ):
		self.change = desc[ "change" ]
		self.user = desc[ "user" ]
		self.client = desc[ "client" ]
		self.desc = desc[ "desc" ]
		self.time = datetime.utcfromtimestamp( int( desc[ "time" ] ) )
		self.status = desc[ "status" ]
		
		self.files = []
		if "depotFile" in desc:
			for n, d in enumerate( desc[ "depotFile" ] ):
				df = P4.DepotFile(d)
				dr = df.new_revision()
				dr.type = desc[ "type" ][ n ]
				dr.rev = desc[ "rev" ][ n ]
				dr.action = desc[ "action" ][ n ]
				self.files.append( df )
		
		self.jobs = {}
		if "job" in desc:
			for n, j in enumerate( desc[ "job" ] ):
				self.jobs[j] = desc[ "jobstat" ][ n ]

DEFAULT_LOG = "p4triggers.log"

class P4Trigger:
	"""Base class for Perforce Triggers"""
	
	def __init__( self, **kargs):
		"""Constructor for P4Trigger. 
		   Keyword arguments are passed to the P4.P4() instance used"""
		
		logFileName = DEFAULT_LOG
		if "log" in kargs:
			logFileName = kargs["log"]
			del kargs["log"]
		
		self.log = open(logFileName, "a+")
	
		self.p4 = P4.P4(**kargs)
		
	def parseChange( self, changeNo ):
		try:
			self.p4.connect()
			self.setUp()
			
			self.change = self.getChange( changeNo )
			return 0 if self.validate() else 1
		except P4.P4Exception as err:
			return self.reportError(err)
		except:
			print("Exception during trigger execution: %s %s %s" % sys.exc_info(), file=self.log)
			return 1
		
		return 0
		
	def getChange( self, changeNo ):
		return P4Change( self.p4.run_describe( changeNo )[0] )
		
	def validate( self ):
		return True
	
	# method that sublasses can overwrite in order to complete the setup of P4 connection
	def setUp( self ):
		pass
	
	#
	# Method to send a message to the user. Just writes to stdout, but it's
	# nice to encapsulate that here.
	#
	def message( self, msg ):
		print( msg )

	def reportError( self , err ):
		"""Method to encapsulate error reporting to make sure
		   all errors are reported in a consistent way"""
		print( "Error during trigger execution:", file=self.log )
		self.reportP4Errors( self.log )
		print( sys.exc_info(), file=self.log ) 
		
		# return message to the user
		self.errorMessage()
		self.reportP4Errors( sys.stdout )
		
		return 1
	
	def reportP4Errors( self, channel ):
		for e in self.p4.errors:
			print( "ERROR: %s" % e, file=channel )
		for w in self.p4.warnings:
			print( "WARNING: %s" % w, file=channel )
 
		return 1
		
	# Default message for when things go wrong
	def errorMessage( self ):
		return """
	An error was encountered during trigger execution. Please
	contact your Perforce administrator and ask them to
	investigate the cause of this error
	"""
		
	
