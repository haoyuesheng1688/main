
Dim Path
Dim fs,f
Dim  i, j,field2
Dim  field'(99999)
Dim MaxLines
Dim data_ID(99999)
Dim data_T(99999)
Dim data_1(99999)
Dim data_2(99999)
Dim data_3(99999)
Dim data_4(99999)
Dim data_5(99999)
Dim data_6(99999)
Dim data_7(99999)
Dim data_8(99999)
Dim data_9(99999)
Dim data_10(99999)
Dim data_11(99999)
Dim SizeOfFile
Dim Lines,sumPag,CurtPag,startLines,endLines
Dim stime,etime,dt,sDiffMin,SdiffMax

If SmartTags("VBS_Run")=1 Then
	'Exit Sub
Else
	SmartTags("VBS_Run")=1
End If

If SmartTags("开始时间")<SmartTags("结束时间") Then
	stime = SmartTags("开始时间")
	etime=SmartTags("结束时间")
Else
	etime = SmartTags("开始时间")
	stime=SmartTags("结束时间")	
End If


'指定日志文件所在目录
Path = "\Storage Card USB\DATA1\DATA10.txt"'"\\DESKTOP-CEFLV5H\winccprojects\DATA10.csv"
'读取日志文件
SmartTags("data_执行说明")="读取日志文件中"
'Set fs = CreateObject("Scripting.FileSystemObject")
Set fs = CreateObject("FileCtl.file")
SmartTags("data_执行说明")="FileCtr完成"
'Set f = fs.OpenTextFile(Path,1,1)
'field = f.ReadAll
'field = Split(field,vbCrLf)
'获取日志文件数量
MaxLines = 0

fs.open Path,1,1
SizeOfFile = fs.lof
Do While fs.EOF <>True
	'field(MaxLines) = fs.lineinputstring
	'MaxLines = MaxLines +1
	field = CStr(fs.inputB(SizeOfFile))
Loop
SmartTags("data_执行说明")="归档文件读取完成"
field = Split(field,vbCrLf)
Lines=UBound(field,1)-3
'Lines = MaxLines-3
'判断是否有归档数据
If Lines <1 Then
	SmartTags("data_执行说明")="不存在归档信息"
	Exit Sub
End If

'收集

Dim Find1
For i =0 To Lines
	
	field2 = Replace(field(i + 1 ),Chr(34),"")
	field2 =Split(field2 ,vbTab)
	
	Dim adrr 
	adrr = InStr(field2(2),".")
	field2(2) = Left(field2(2),adrr+1)
	If field2(0) = "PV_JF进风温度" Then
		If SmartTags("启用时间段搜索") Then 
			dt = field2(1)
			SmartTags("data_执行说明")="时间" & dt
			sDiffMin = DateDiff("s",stime,dt)
			SdiffMax = DateDiff("s",dt,etime)
			'SmartTags("data_执行说明")="时间段" & sDiffMin & "-" & SdiffMax
		Else
			sDiffMin = 1
			SdiffMax = 1
		End If
		If (sDiffMin > 0) And (SdiffMax>0)  Then
			Find1=Find1+1	
			data_ID(Find1-1) = Find1
			data_T(Find1-1) = field2(1)
			data_1(Find1-1) = field2(2)
		End If
	End If
	If Find1>99999 Then
		Exit For	
	End If
	If Find1 > 0 Then 
		If field2(0) = "PV_CF出风温度" Then
			data_2(Find1-1) = field2(2)
		
		End If
		
		If field2(0) = "PV_GX高效压差" Then
			data_3(Find1-1) = field2(2)
		End If
	
		If field2(0) = "PV_BD布袋压差" Then
			data_4(Find1-1) = field2(2)
		End If
	 
		If field2(0) = "PV_CF出风高温高效" Then
			data_5(Find1-1) = field2(2)
		End If
	
		If field2(0) = "PV_TN塔内压力" Then
			data_6(Find1-1) = field2(2)
		End If
	
		If field2(0) = "PV_SF送风反馈" Then
			data_7(Find1-1) = field2(2)
		End If

		If field2(0) = "PV_LX离心雾化" Then
			data_8(Find1-1) = field2(2)
		End If
	
		If field2(0) = "PV_YF引风反馈" Then
			data_9(Find1-1) = field2(2)
		End If

		If field2(0) = "PV_C称重仪" Then
			data_10(Find1-1) = field2(2)
		End If

		

	End If
		
	
Next
'显示日志数据

If Find1 <1 Then
	SmartTags("data_执行说明")="当前时间段不存在归档信息"
	Exit Sub
End If
sumPag = Find1 \ 15
If (sumPag *15)< Find1 Then	
	sumPag =sumPag +1
End If
SmartTags("变量记录总页数")=sumPag
CurtPag = SmartTags("变量记录当前页数")
If (CurtPag < 1) Or (CurtPag>sumPag) Then
	CurtPag = 1
	SmartTags("变量记录当前页数")=CurtPag
End If
startLines = (CurtPag-1) * 15
SmartTags("data_执行说明")="显示数据" & Find1 & "-" & startLines
	For i =1 To 15
	If startLines+i < Find1 Then
		SmartTags("data_id_" & i) = startLines + i
		SmartTags("data_时间_" & i) = data_T(startLines + i-1)

	
		SmartTags("data_进风温度_" & i) = data_1(startLines + i-1)
				
		
		SmartTags("data_出风温度_" & i) = data_2(startLines + i-1)
	
		SmartTags("data_高效压差_" & i) = data_3(startLines + i-1)
	
		SmartTags("data_布袋压差_" & i) = data_4(startLines + i-1)
	
		SmartTags("data_出口压差_" & i) =data_5(startLines + i-1)
	
		SmartTags("data_塔内压力_" & i) =data_6(startLines + i-1)
	
		SmartTags("data_送风频率_" & i) =data_7(startLines + i-1)
	
		SmartTags("data_雾化频率_" & i) =data_8(startLines + i-1)
		
		SmartTags("data_引风频率_" & i) =data_9(startLines + i-1)

		SmartTags("data_称重仪_" & i) =data_10(startLines + i-1)
	
	
	Else
		SmartTags("data_id_" & i) =startLines + i
		SmartTags("data_时间_" & i) = ""
		SmartTags("data_进风温度_" & i) = 0.0
		SmartTags("data_出风温度_" & i) = 0.0
		SmartTags("data_高效压差_" & i) = 0.0
		SmartTags("data_布袋压差_" & i) = 0.0
		SmartTags("data_出口压差_" & i) = 0.0
		SmartTags("data_塔内压力_" & i) = 0.0
		SmartTags("data_送风频率_" & i) = 0.0
		SmartTags("data_雾化频率_" & i) = 0.0
		SmartTags("data_引风频率_" & i) = 0.0
		SmartTags("data_称重仪_" & i) = 0.0
		
	
	End If
	Next
	SmartTags("data_执行说明")="归档数据加载完成"	
	'SmartTags("data_执行说明")=field2(2)
	
	SmartTags("VBS_Run")=0
	fs.close
	Set  fs  = Nothing

