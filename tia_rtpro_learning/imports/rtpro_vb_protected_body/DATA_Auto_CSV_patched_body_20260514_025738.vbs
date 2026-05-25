'提示：
' 1. 使用 <CTRL+SPACE> 或 <CTRL+I> 快捷键打开含所有对象和函数的列表
' 2. 使用 HMI Runtime 对象写入代码。
'  示例：HmiRuntime.Screens("Screen_1")。
' 3. 使用 <CTRL+J> 快捷键创建对象引用。
'从此位置起写入代码：

On Error  Resume Next

Dim st,et
st =SmartTags("last_back_date").Value
et = Now

If DateDiff("d",st,et) < SmartTags("back_days") Then
	Exit Sub
End If
'添加要查询的变量名称
Dim TagName(9),iLen
TagName(0) = "DATA1\进风温度"
TagName(1) = "DATA1\出风温度"
TagName(2) = "DATA1\尾气温度"
TagName(3) = "DATA1\进风高效压差"
TagName(4) = "DATA1\出风高效压差"
TagName(5) = "DATA1\布袋压差"
TagName(6) = "DATA1\塔内压力"
TagName(7) = "DATA1\管道压力"
TagName(8) = "DATA1\露点温度"


TagName(9) = "DATA1\环境检测"
iLen =UBound(TagName)

Dim DTP1,DTP2
'获取查询时间段
DTP1=st
DTP2=et
st = DateAdd("h",-8,DTP1)
st = Year(st) & "-" & Month(st) & "-" & Day(st) & " " & Hour(st) & ":" & Minute(st) & ":" & Second(st)
et = DateAdd("h",-8,DTP2)
et = Year(et) & "-" & Month(et) & "-" & Day(et) & " " & Hour(et) & ":" & Minute(et) & ":" & Second(et)
'创建数据库连接
Dim i,j
Dim conn,comm,record,sql
Set conn = CreateObject("ADODB.Connection")
conn.CursorLocation = 3 
conn.Open "Provider=WINCCOLEDBProvider.1;catalog=" & SmartTags("@DatasourceNameRT") & ";Data Source=.\WinCC"


Set comm = CreateObject("ADODB.Command")
Set record = CreateObject("ADODB.RecordSet")
Set comm.ActiveConnection = conn
'查询语句
For i = 0 To iLen
	If i = 0 Then
		sql =  "'"& TagName(i) &"'"
	Else 
		sql =sql & ";" &   "'"& TagName(i) &"'"
	End If
Next
sql = "Tag:R,(" & sql & "),'"& st &"','"& et &"'" 
comm.CommandText = sql

Set record = comm.Execute
Dim rsCount 
rsCount= record.recordcount
Dim ListCount
ListCount =rsCount/(iLen+1)

Dim strList()
ReDim strList(ListCount)

If rsCount > 0 Then
	record.movefirst
	Dim fCount 
	fCount = record.fields.count
	
	Dim sRn,indx,Rowidx,Colidx,TagID,RowCount,ColNo,ColTime,ColValue

	For i = 0 To rsCount -1
		TagID =record.fields("ValueID").value
		ColTime =DateAdd("h",8, record.fields("Timestamp").value)
		ColValue = Round(record.fields("RealValue").value,2)
		If TagID <> sRn Then	
			sRn = TagID
			Colidx = Colidx +1
			Rowidx =0   
		End If
		If Colidx = 1 Then
			ColNo = ColNo +1
			If Rowidx <= ListCount Then 
				strList(Rowidx) = ColNo & "," & ColTime & "," & ColValue
			End If
			Rowidx = Rowidx +1
		Else
			If Rowidx <= ListCount  Then
				strList(Rowidx)= strList(Rowidx) & "," & ColValue
				
			End If
			Rowidx = Rowidx +1
		End If
		record.movenext
	Next
End If

If Not record Is Nothing Then
    If record.State = 1 Then record.Close
    Set record = Nothing
End If
Set comm = Nothing
If Not conn Is Nothing Then
    If conn.State = 1 Then conn.Close
    Set conn = Nothing
End If



Dim CsvName
CsvName = Year(DTP1)  & Right("0" & Month(DTP1),2)  & Right("0" & Day(DTP1),2)  &  Right("0" & Hour(DTP1),2) & Right("0" & Minute(DTP1),2) & Right("0" & Second(DTP1),2)
CsvName = CsvName & "_" & Year(DTP2)  &  Right("0" & Month(DTP2),2)  & Right("0" & Day(DTP2),2)  &  Right("0" & Hour(DTP2),2) & Right("0" & Minute(DTP2),2) & Right("0" & Second(DTP2),2)
CsvName = CsvName & ".csv"
Dim pathname
Dim fs ,file

Set fs = CreateObject("Scripting.FileSystemObject")
pathname = "D:\自动导出数据" 
If Not fs.FolderExists(pathname) Then
	fs.CreateFolder(pathname)
End If
pathname = "D:\自动导出数据\归档数据" 
If Not fs.FolderExists(pathname) Then
	fs.CreateFolder(pathname)
End If
Set  file = fs.CreateTextFile(pathname & "\" & CsvName,True)
Dim title
title = "序号," & "时间"
For i = 0 To iLen
	title = title & "," & Replace(TagName(i),"DATA1\","")
Next
file.WriteLine  title
Dim src 
For i=0 To ListCount
	file.WriteLine strList(i)
Next 


file.Close

Set file = Nothing
Set fs = Nothing

SmartTags("last_back_date") = DTP2