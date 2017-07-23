#tag Class
Protected Class ControlPacket
Implements zd.Utils.DataStructures.PushableItem
	#tag Method, Flags = &h0
		Sub Constructor(inType As MQTTLib.ControlPacket.Type, inData As MQTTLib.ControlPacketOptions = Nil)
		  //-- This is the constructor when the packet is to be send to the broker
		  
		  Self.pType = inType
		  Self.pPacketData = inData
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(inTypeAndFlags As UInt8, inData As MemoryBlock)
		  
		  // Extract and set the fixed header flags
		  Dim theFlags( 3 ) As Boolean
		  
		  theFlags( 0 ) = ( inTypeAndFlags And zd.Utils.Bits.kValueBit0 ) > 0
		  theFlags( 1 ) = ( inTypeAndFlags And zd.Utils.Bits.kValueBit1 ) > 0
		  theFlags( 2 ) = ( inTypeAndFlags And zd.Utils.Bits.kValueBit2 ) > 0
		  theFlags( 3 ) = ( inTypeAndFlags And zd.Utils.Bits.kValueBit3 ) > 0
		  
		  // Extract and set the packet type and prepare the data
		  Dim thePacketType As Integer = inTypeAndFlags \ zd.Utils.Bits.kValueBit4
		  
		  Select Case thePacketType
		    
		  Case Integer( MQTTLib.ControlPacket.Type.CONNECT )
		    pType = MQTTLib.ControlPacket.Type.CONNECT
		    Self.pPacketData = New MQTTLib.OptionsCONNECT
		    
		  Case Integer( MQTTLib.ControlPacket.Type.CONNACK )
		    pType = MQTTLib.ControlPacket.Type.CONNACK
		    Self.pPacketData = New MQTTLib.OptionsCONNACK
		    
		  Case Integer( MQTTLib.ControlPacket.Type.PINGREQ )
		    pType = MQTTLib.ControlPacket.Type.PINGREQ
		    
		  Case Integer( MQTTLib.ControlPacket.Type.PINGRESP )
		    pType = MQTTLib.ControlPacket.Type.PINGRESP
		    
		  Case Integer( MQTTLib.ControlPacket.Type.SUBACK )
		    pType = MQTTLib.ControlPacket.Type.SUBACK
		    Self.pPacketData = New MQTTLib.OptionsSUBACK
		    
		  Case Integer( MQTTLib.ControlPacket.Type.PUBLISH )
		    pType = MQTTLib.ControlPacket.Type.PUBLISH
		    Dim theOptionsPUBLISH As New MQTTLib.OptionsPUBLISH
		    
		    // Set the flags and the QoS
		    theOptionsPUBLISH.RETAINFlag = theFlags( 0 )
		    theOptionsPUBLISH.DUPFlag = theFlags( 3 )
		    
		    Select Case If( theFlags( 1 ), zd.Utils.Bits.kValueBit0, 0 ) + If( theFlags( 2 ), zd.Utils.Bits.kValueBit1, 0 )
		      
		    Case Integer( MQTTLib.QoS.AtMostOnceDelivery )
		      theOptionsPUBLISH.QoSLevel = MQTTLib.QoS.AtMostOnceDelivery
		      
		    Case Integer( MQTTLib.QoS.AtLeastOnceDelivery )
		      theOptionsPUBLISH.QoSLevel = MQTTLib.QoS.AtLeastOnceDelivery
		      
		    Case Integer( MQTTLib.QoS.ExactlyOnceDelivery )
		      theOptionsPUBLISH.QoSLevel = MQTTLib.QoS.ExactlyOnceDelivery
		      
		    End Select
		    
		    Self.pPacketData = theOptionsPUBLISH
		    
		  Case Integer( MQTTLib.ControlPacket.Type.PUBACK )
		    pType = MQTTLib.ControlPacket.Type.PUBACK
		    Self.pPacketData = New MQTTLib.OptionsPUBXXX
		    
		  Case Integer( MQTTLib.ControlPacket.Type.PUBREC )
		    pType = MQTTLib.ControlPacket.Type.PUBREC
		    Self.pPacketData = New MQTTLib.OptionsPUBXXX
		    
		  Case Integer( MQTTLib.ControlPacket.Type.PUBREL )
		    pType = MQTTLib.ControlPacket.Type.PUBREL
		    Self.pPacketData = New MQTTLib.OptionsPUBXXX
		    
		  Case Integer( MQTTLib.ControlPacket.Type.PUBCOMP )
		    pType = MQTTLib.ControlPacket.Type.PUBCOMP
		    Self.pPacketData = New MQTTLib.OptionsPUBXXX
		    
		  Else
		    // Unsupported Command
		    Raise New MQTTLib.ProtocolException( CurrentMethodname, _
		    "Unsupported packet type " + Str( thePacketType ) + ".", _
		    MQTTLib.Error.UnsupportedControlPacketType )
		    
		  End Select
		  
		  // --- Checking for data inconsistencies ---
		  
		  If Self.pPacketData Is Nil And Not ( inData Is Nil ) Then
		    // The packet type has no data, but we found some
		    Raise New MQTTLib.ProtocolException( CurrentMethodName, _
		    "Data were parsed but the packet type (" + Str( thePacketType ) + ") doesn't need data.", _
		    MQTTLib.Error.ControlPacketDoesntNeedData )
		    
		  Elseif Not( Self.pPacketData Is Nil ) Then 
		    
		    If  inData Is Nil Then
		      // The packet type needs data, but none were parsed
		      Raise New MQTTLib.ProtocolException( CurrentMethodName, _
		      "The packet type (" + Str( thePacketType ) + ") needs data, but none were parsed", _
		      MQTTLib.Error.ControlPacketNeedsData )
		      
		    Else
		      // The packet type needs data, and we have some.
		      // Sets it endianness
		      inData.LittleEndian = False
		      
		      // And parse it
		      Self.pPacketData.ParseRawData( inData )
		      
		    End If
		    
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Shared Function EncodeRemainingLength(inLength As UInteger) As String
		  //-- Encode the passed value in 7 bits byte(s) as described in the MQTT protocol
		  
		  // Raise an exception if its exceeds the 28 bits size limit
		  If inLength >= zd.Utils.Bits.kValueBit28 Then _
		  Raise New MQTTLib.ProtocolException( CurrentMethodName, "A remaining length of " + Str( inLength ) + " exceeds the limit of 268,435,555 bytes.", _
		  MQTTLib.Error.RemainingLengthExceedsMaximum )
		  
		  Dim X As UInteger = inLength
		  Dim theParts() As String
		  
		  Do
		    Dim theEncodedByte As UInteger = X Mod 128
		    X = X \ zd.Utils.Bits.kValueBit7
		    
		    // If there are more data to encode, set the top bit of this byte
		    If X > 0 Then theEncodedByte = theEncodedByte Or zd.Utils.Bits.kValueBit7
		    
		    theParts.Append ChrB( theEncodedByte ) 
		    
		  Loop Until X = 0
		  
		  Return Join( theParts, "" )
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Flag(inIndex As Integer) As Boolean
		  //-- Return a fixed header flag value given its index
		  
		  If inIndex < 0 Or inIndex > 3 Then
		    // inIndex is out of bounds so raise a well documented exception
		    Raise New zd.EasyOutOfBoundsException( CurrentMethodName, "inIndex is " + Str( inIndex ) + " but there is only 4 flags (0-3) in the fixed header." )
		    
		  Else
		    // Gets the value of the flag
		    Return Self.pFixedHeaderFlags( inIndex )
		    
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Flag(inIndex As Integer, Assigns inFlag As Boolean)
		  //-- Return a fixed header flag value given its index
		  
		  If inIndex < 0 Or inIndex > 3 Then
		    // inIndex is out of bounds so raise a well documented exception
		    Raise New zd.EasyOutOfBoundsException( CurrentMethodName, "inIndex is " + Str( inIndex ) + " but there is only 4 flags (0-3) in the fixed header." )
		    
		  Else
		    // Sets the value of the flag
		    Self.pFixedHeaderFlags( inIndex ) = inFlag
		    
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetNextItem() As zd.Utils.DataStructures.PushableItem
		  // Part of the zd.Utils.DataStructures.PushableItem interface.
		  
		  Return Self.pNextPushableHook
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Options() As MQTTLib.ControlPacketOptions
		  //--- Returns the optional data
		  
		  Return Self.pPacketData
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function RawData() As String
		  //-- Compute the data in the binary form
		  
		  // ---- Calculate the type and flags byte for the fixed header ----
		  Dim theFirstByte As UInt8 = If( Self.pFixedHeaderFlags( 0 ), zd.Utils.Bits.kValueBit0, 0 ) _
		  + If( Self.pFixedHeaderFlags( 1 ), zd.Utils.Bits.kValueBit1, 0 ) _
		  + If( Self.pFixedHeaderFlags( 2 ), zd.Utils.Bits.kValueBit2, 0 ) _
		  + If( Self.pFixedHeaderFlags( 3 ), zd.Utils.Bits.kValueBit3, 0 ) _
		  + Integer( Self.pType ) * zd.Utils.Bits.kValueBit4
		  
		  Dim theDataSize As UInteger
		  Dim theData As String
		  
		  // Retrieve the payload data if there is one
		  If Not ( Self.pPacketData Is Nil ) Then
		    theData = Self.pPacketData.GetRawdata
		    theDataSize = theData.LenB
		    
		  End If
		  
		  // Return the data
		  Return ChrB( theFirstByte ) + MQTTLib.ControlPacket.EncodeRemainingLength( theDataSize ) + theData
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetNextItem(inNextItem As zd.Utils.DataStructures.PushableItem)
		  // Part of the zd.Utils.DataStructures.PushableItem interface.
		  
		  Self.pNextPushableHook = inNextItem
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h21
		Private pFixedHeaderFlags(3) As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private pNextPushableHook As zd.Utils.DataStructures.PushableItem
	#tag EndProperty

	#tag Property, Flags = &h21
		Private pPacketData As MQTTLib.ControlPacketOptions
	#tag EndProperty

	#tag Property, Flags = &h21
		Private pType As MQTTLib.ControlPacket.Type
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  // Return the type of the control packet
			  
			  Return Self.pType
			End Get
		#tag EndGetter
		Type As MQTTLib.ControlPacket.Type
	#tag EndComputedProperty


	#tag Enum, Name = Type, Type = Integer, Flags = &h0
		CONNECT = 1
		  CONNACK = 2
		  PUBLISH = 3
		  PUBACK = 4
		  PUBREC = 5
		  PUBREL = 6
		  PUBCOMP = 7
		  SUBSCRIBE = 8
		  SUBACK = 9
		  UNSUBSCRIBE = 10
		  UNSUBACK = 11
		  PINGREQ = 12
		  PINGRESP = 13
		DISCONNECT = 14
	#tag EndEnum


	#tag ViewBehavior
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