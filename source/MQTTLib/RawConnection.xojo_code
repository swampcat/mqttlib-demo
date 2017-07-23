#tag Class
Protected Class RawConnection
	#tag Method, Flags = &h0
		Sub Close()
		  //-- Let's close the socket connection
		  
		  Self.pSocketAdapter.Disconnect
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(inSocketAdapter As MQTTLib.SocketAdapter)
		  //-- Sets and patch the socket adapter
		  
		  // Cache a reference to the socket adpater
		  Self.pSocketAdapter = inSocketAdapter
		  
		  // A bit of wiring
		  inSocketAdapter.RegisterDelegates( _
		  AddressOf Self.HandleSocketAdapterConnected, _
		  AddressOf Self.HandleSocketAdapterNewData, _
		  AddressOf Self.HandleSocketAdapterError )
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub HandleSocketAdapterConnected()
		  //-- The socket layer is connected, connect to the MQTT broker
		  
		  Self.pConnected = True
		  RaiseEvent Connected
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub HandleSocketAdapterError(inError AS MQTTLib.Error)
		  //-- There was an error with the socket adapter
		  
		  // Error always means disconnection
		  Self.pConnected =  False
		  
		  Dim theError As MQTTLib.Error
		  
		  // Was the connection closed after a protocol error?
		  If Self.pProtocolError <> MQTTLib.Error.NoError And inError = MQTTLib.Error.LostConnection Then
		    // Yes, grab the protocol error and reset it cache
		    theError = Self.pProtocolError
		    Self.pProtocolError = MQTTLib.Error.NoError
		    
		  Else
		    // This a socket adapter error
		    theError = inError
		    
		  End If
		  
		  // Signal the subclass
		  RaiseEvent Error( theError )
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub HandleSocketAdapterNewData(inNewData As String)
		  //-- Process new incoming data
		  
		  Const kRemainingLengthValueMax = &b01111111
		  
		  // Assemble the remaining and the new data and cast the result to a MemoryBlock
		  Dim theRawData As MemoryBlock = Self.pDataRemainder + inNewData
		  
		  // This is the endless loop to process the raw data until there is no more complete packets
		  // There are exit conditions when no more data are avalaible or they are incomplete 
		  Do
		    
		    // A packet should at least be 2 bytes long 
		    If theRawData.Size < 2 Then
		      // Store the data and return
		      Self.pDataRemainder = theRawData
		      Return
		      
		    End If
		    
		    // ---- Compute the remaining length ----
		    
		    Dim theOffset As Integer = 1
		    Dim theMultiplier As Integer = 1
		    Dim theRemainingLentgh As Integer
		    Dim theByte As Byte
		    
		    Do
		      
		      // Check For not enough data
		      If theOffset >= theRawData.Size Then
		        // The data are incomplete
		        Self.pDataRemainder = theRawData
		        Return
		        
		      End If
		      
		      // Read the byte
		      theByte = theRawData.Byte( theOffset )
		      theOffset = theOffset + 1
		      
		      // Compute the value
		      theRemainingLentgh = theRemainingLentgh + ( theByte And kRemainingLengthValueMax ) * theMultiplier
		      
		      // Check for error
		      If theMultiplier > zd.Utils.Bits.kValueBit7^3 Then
		        // The fixed header is malformed, close the connection
		        Self.pProtocolError = MQTTLib.Error.MalformedFixedHeader
		        Self.Close()
		        Return
		        
		      End If
		      
		      theMultiplier = theMultiplier * zd.Utils.Bits.kValueBit7
		      
		    Loop Until ( theByte And zd.Utils.Bits.kValueBit7 ) = 0 
		    
		    // ---- Calculate and check the block size needed to get a complete packet ----
		    
		    Dim thePacketSize As Integer = theOffset + theRemainingLentgh
		    If thePacketSize > theRawData.Size Then
		      // The data are incomplete
		      Self.pDataRemainder = theRawData
		      Return
		      
		    End If
		    
		    // We have enough data, extract them
		    Dim thePacketTypeAndFlag As UInt8 = theRawData.Byte( 0 )
		    Dim theOptionsData As MemoryBlock
		    If theRemainingLentgh > 0 Then theOptionsData = theRawData.MidB( theOffset, theRemainingLentgh )
		    
		    // Send the new Data
		    Try
		      RaiseEvent ControlPacketReceived New MQTTLib.ControlPacket( thePacketTypeAndFlag, theOptionsData )
		      
		    Catch e As MQTTLib.ProtocolException
		      // There was a problem when creating the ControlPacket
		      // Store the protocol error
		      Self.pProtocolError = e.ProtocolError
		      Self.Close()
		      
		    End Try
		    
		    // Extract and store the remaining data if needed
		    If theRawData.Size < thePacketSize Then
		      Self.pDataRemainder = theRawData.RightB( theRawData.Size - thePacketSize )
		      
		    Else
		      // No data remaining
		      Self.pDataRemainder = ""
		      Return
		      
		    End If
		    
		    // Let's go for another round
		    theRawData = Self.pDataRemainder
		    
		  Loop
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub JettisonSocketAdapter()
		  //-- Unlink the socket adapter
		  
		  // Only if we have an existing socket adapter
		  If Not ( Self.pSocketAdapter Is Nil ) Then
		    // Unlink the socket adpaters delegates
		    Self.pSocketAdapter.RemoveDelegates
		    
		    // Destroy the socket adapater
		    Self.pSocketAdapter = Nil
		    
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Open()
		  // Connect the socket adapter
		  
		  Self.pSocketAdapter.Connect
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SendControlPacket(inPacket As MQTTLib.ControlPacket)
		  //-- Send the packet to the broker
		  
		  // --- Check the session state ---
		  If Not Self.Connected Then _
		  Raise New MQTTLib.ProtocolException( CurrentMethodName, "The socket adapter is not connected.", _
		  MQTTLib.Error.SocketAdapterNotConnected )
		  
		  // We're clear to send
		  Self.pSocketAdapter.SendControlPacket inPacket
		End Sub
	#tag EndMethod


	#tag Hook, Flags = &h0
		Event Connected()
	#tag EndHook

	#tag Hook, Flags = &h0
		Event ControlPacketReceived(inControlPacket As MQTTLib.ControlPacket)
	#tag EndHook

	#tag Hook, Flags = &h0
		Event Error(inError As MQTTLib.Error)
	#tag EndHook


	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Return pConnected
			End Get
		#tag EndGetter
		Connected As Boolean
	#tag EndComputedProperty

	#tag Property, Flags = &h21
		Private pConnected As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private pDataRemainder As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private pDisconnecting As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private pProtocolError As MQTTLib.Error = MQTTLib.Error.NoError
	#tag EndProperty

	#tag Property, Flags = &h21
		Private pSocketAdapter As MQTTLib.SocketAdapter
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Return Me.pSocketAdapter
			End Get
		#tag EndGetter
		SocketAdapter As MQTTLib.SocketAdapter
	#tag EndComputedProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="Connected"
			Group="Behavior"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass