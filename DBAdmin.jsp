<%@ page contentType="text/html; charset=utf-8" language="java" import="java.sql.*,java.util.*" errorPage="" %>
<%
/*
 * MIT License
 * Author: shennan (amushen@gmail.com)
 * 2014/09/23
 * 
 */
	final String MySQLDBDriver="org.gjt.mm.mysql.Driver";
	final String MySQLDBURL="jdbc:mysql://<<SERVERIP>>/<<DBNAME>>";	
	
	final String MSSQLDBDriver="com.microsoft.jdbc.sqlserver.SQLServerDriver";
	final String MSSQLDBURL="jdbc:sqlserver://<<SERVERIP>>";

	final int MAX_ROWS=100;	//max rows in query result
%><%
//Gloab variable declare
	
	String user;	//db user saved into session
	String password;//db password saved into session

	String message;//for show message

//gloab class define
	class Log{
		public void debug(String msg){
			System.out.println(msg);
		}
		public void warn(String msg){
			System.out.println(msg);
		}
	}
	
	//define log varible
	final Log log=new Log();

	/**
	 * Base Class for DBUtil
	 */ 
	abstract class BaseDBUtil{
	
		protected Connection conn;		
		protected ResultSet rs;
		protected int updateCount;

		/**
		 * commone getConnection logic
		 */		
		protected Connection getConn(String user,String password,String url,String driver){			
			if(conn!=null)return conn;
			try{
				Class.forName(driver).newInstance();
				conn=DriverManager.getConnection(url,user,password);
			}catch(Exception e){
				log.warn(e.getMessage());
				e.printStackTrace();
				request.setAttribute("message",e.getMessage());
			}
			return conn;
		}
		/**
		 * execute sql which user input
		 */
		public void execute(String sql){			
			if(conn==null)return;
			try{
				Statement stat=conn.createStatement();
				stat.execute(sql);
				rs=stat.getResultSet();
				updateCount=stat.getUpdateCount();								
			}catch(Exception e){
				log.warn(e.getMessage());
				request.setAttribute("message",e.getMessage());
			}
		}
		
		/**
		 * get result set for showing
		 */
		public ResultSet getResult(){
			return rs;
		}
		/**
		 * get update count
		 */
		public int getUpdateCount(){
			return updateCount;
		}
		
		/** 
		 * convert resultset to string table.
		 * the first row is the table's header
		 */
		public List<String[]> getResultTable(){
			ArrayList<String[]> ret=new ArrayList<String[]>();
			if(rs==null)return ret;			
			int total=0;
			try{
				//get title
				ResultSetMetaData meta=rs.getMetaData();
				int columnCount=meta.getColumnCount();
				String title[]=new String[columnCount];
				for(int i=1;i<=columnCount;i++){
					title[i-1]=meta.getColumnName(i);
				}
				ret.add(title);
				//get result
				while(rs.next()){									
					total++;
					if(total>MAX_ROWS)break;//for max rows limit
					String row[]=new String[columnCount];
					for(int i=1;i<=columnCount;i++){
						Object obj=rs.getObject(i);
						if(obj==null)
							row[i-1]="";
						else
							row[i-1]=obj.toString();		
					}
					ret.add(row);
				}
				rs.close();
				rs=null;				
			}catch(Exception e){
				log.warn(e.getMessage());
				request.setAttribute("message",e.getMessage());
			}
			return ret;
		}
		
		/**
		 * get width of every column
		 */
		 
		 public int[] getColumnWidth(){
		 	if(rs==null)return null;
			int widths[]=null;
			try{
				//get title
				ResultSetMetaData meta=rs.getMetaData();
				int columnCount=meta.getColumnCount();
				widths=new int[columnCount];				
				for(int i=1;i<=columnCount;i++){
					widths[i-1]=meta.getPrecision(i);
				}
			}catch(Exception e){
				log.warn(e.getMessage());
			}
			return widths;
		 }

		/**
		 * close db connection
		 */
		public void close(){
			if(rs!=null){
				try{
					rs.close();
					rs=null;
				}catch(Exception e){}
			}
		
			if(conn!=null){
				try{
					conn.close();
					conn=null;
				}catch(Exception e){
					log.warn(e.getMessage());
					request.setAttribute("message",e.getMessage());
				}
			}
		}
		public List<String[]> listTables(String dbname){
			execute("select table_name from information_schema.tables where TABLE_SCHEMA='"+dbname+"';");
			return getResultTable();
		}
		
		public List<String[]> listDatabases(){		
			execute("select distinct schema_name from information_schema.SCHEMATA;");
			return getResultTable();
		}
		
		
		
		public abstract Connection getConnection(String user,String password,String serverIP,String dbname);
		
	}
	

	
	/**
	 * MySql DBUtil
	 */
	class MYSQLDBUtil extends BaseDBUtil{
		
		public Connection getConnection(String user,String password,String serverIP,String dbname){
			if(serverIP==null||serverIP.length()<1) serverIP="localhost";
			if(dbname==null||dbname.length()<1 || "null".equals(dbname))dbname="";
			
			String url=MySQLDBURL.replace("<<SERVERIP>>",serverIP);
			url=url.replace("<<DBNAME>>",dbname);
			url=url+"?characterEncoding=utf-8";
			conn=null;
			try{
				conn=getConn(user,password,url,MySQLDBDriver);
			}catch(Exception e){
				log.warn(e.getMessage());
				request.setAttribute("message",e.getMessage());
			}
			return conn;
		}
	}
	
	
	/**
	 * for mssql db
	 */
	 
	 class MSSQLDBUtil extends BaseDBUtil{
	 
		 public Connection getConnection(String user,String password,String serverIP,String dbname){
			if(serverIP==null||serverIP.length()<1) serverIP="localhost";
			if(dbname==null||dbname.length()<1)dbname="";
			
			String url=MSSQLDBURL.replace("<<SERVERIP>>",serverIP);
			if(dbname.length()>0){
				url=url+";databasename="+dbname;
			}
			log.debug(url);
			conn=null;
			try{
				conn=getConn(user,password,url,MSSQLDBDriver);
			}catch(Exception e){
				log.warn(e.getMessage());
				request.setAttribute("message",e.getMessage());
			}
			return conn;
		}	 
		
		
		public List<String[]> listTables(String dbname){
			execute("select name from sysobjects where xtype='U';");
			return getResultTable();
		}
		
		
		public List<String[]> listDatabases(){		
			execute("select Name from master..sysdatabases");
			return getResultTable();
		}
		
	 }
	
	
	//initial database util object	
	BaseDBUtil db=null;
	String dbtype=request.getParameter("hDbType");
	if("MSSQL".equals(dbtype)){
		db=new MSSQLDBUtil();
	}else{
		db=new MYSQLDBUtil();
	}
	
	//get user from session
	user=(String)session.getAttribute("DBUser");
	password=(String)session.getAttribute("DBPassword");

	if(user!=null&&user.length()>0){
		db.getConnection(user,password,request.getParameter("hServerIP"),request.getParameter("dbname"));
	}
	
	if(db==null){
		out.println("DB error.");
		return;
	}
	
%>


<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>DB Admin Tool 1.0</title>
<style>
body{
	margin:0px
}
#resultTable{
border-collapse:collapse;
}
#resultTable td{
	background:#ffffff;
	border:solid 1px #999999;
	height:22px;
}
#resultTable th{
	border:solid 1px #999999;
	background:#e0e0e0;
}
#dbTable{
	width:200px;
	table-layout:fixed
}
#dbTable td{
	overflow:hidden;
}
#tableTable{
	width:200px;
	table-layout:fixed;
}
#tableTable td{
	overflow:hidden;
}

</style>
<script>
	function $(name){
		return document.getElementById(name);
	}
	
	function doLogin(){
		$("cmd").value="login";		
		$("hServerIP").value=$("serverIP").value;
		$("hDbType").value=$("dbtype").value;
		$("dbname").value="";
		$("form1").submit();
	}
	
	function logout(){
		$("cmd").value="logout";
		$("form1").submit();
	}
	
	function selectDB(dbname){
		$("dbname").value=dbname;
		$("cmd").value="db";
		$("form1").submit();
	}
	
	function selectTable(tableName){
		$("cmd").value="execute";
		$("encodeSql").value="select * from "+tableName;
		$("form1").submit();
	}
	
	function doSubmit(){
		$('cmd').value='execute';
		$("encodeSql").value=encodeURI($("sql").value);
		$("form1").submit();
	}
	
	function init(){
		//set width of result table
		var t=$("resultDiv");
		if(t){
			t.style.width=(document.body.clientWidth-220)+"px";
		}
		moveEnd($("sql"));
	}
	
	function moveEnd(obj){ 
	    obj.focus();  
    	var len = obj.value.length;  
	    if (document.selection) {  
	        var sel = obj.createTextRange();  
	        sel.moveStart('character',len);  
	        sel.collapse();  
	        sel.select();  
    	} else if (typeof obj.selectionStart == 'number' && typeof obj.selectionEnd == 'number') {  
	        obj.selectionStart = obj.selectionEnd = len;  
    	} 
 
 
	} 
	
	function doKeyup(event){
		if(event.ctrlKey && (event.keyCode==13))doSubmit();
	}
	
</script>
</head>

<body onload="init()">
<form id="form1" name="form1" method="post" action="">
<%
	String cmd=request.getParameter("cmd");
	if(cmd==null)cmd="";
	log.debug("cmd="+cmd);
	if("login".equals(cmd)){
		String ruser=request.getParameter("dbuser");
		String rpassword=request.getParameter("password");
		
		if(db.getConnection(ruser,rpassword,request.getParameter("hServerIP"),request.getParameter("dbname"))==null){
			//login failed.
			request.setAttribute("message","Login Failed.");
			
		}else{			
			session.setAttribute("DBUser",ruser);
			session.setAttribute("DBPassword",rpassword);
			user=ruser;
			password=rpassword;
		}	
	}
	
	if("logout".equals(cmd)){
		session.removeAttribute("DBUser");
		session.removeAttribute("DBPassword");
		user=null;
		password=null;
		request.removeAttribute("message");
	}

	
 
	if(user==null){
%>
	<table id='loginTable'>
	<tr><td align="right">Database</td><td><select id="dbtype" name="dbtype"><option value="MYSQL">MYSQL</option><option value="MSSQL">MSSQL</option></select></td></tr>
	<tr><td align=right>Server IP</td><td align=left><input id="serverIP" type=text name='serverIP' value="localhost" /></td></tr>
	<tr><td align=right>DB User</td><td align=left><input type=text name='dbuser' value="root" /></td></tr>
	<tr><td align=right>Password</td><td align=left><input type=password name='password' /></td></tr>
	<tr><td colspan=2 align=center><input type=button class="button" onclick='doLogin()' value='Login' /></td></tr></table>
<%
	message=(String)request.getAttribute("message");		
	if(message!=null&&message.length()>0){
		out.println("<div id='message'>"+message+"</div>");
	}
	}else{
	
	
		List<String[]> dbs=db.listDatabases();
		List<String[]> tables=db.listTables(request.getParameter("dbname"));
		log.debug("dbs:"+dbs.size());
		log.debug("tables:"+tables.size());
	
%>
<table id="header" width="100%" border="0" bgColor="#aaaaff" style="color:white">
	<tr height="25">
		<td align="left" style="font-size:25px;"><b>DB Admin Tool</b></td>
		<td align="right"><%=user%>@<%=request.getParameter("hServerIP")%>&nbsp;&nbsp;			
			<a href='javascript:logout()' style='color:white'>Logout</a>&nbsp;
		</td>
	</tr>		
</table>
<table id="layoutTable" width=100% style="table-layout:fixed">

<tr valign="top">
	<td width=200>
		<table id="dbTable" border=0>
			<%//show all databases;
				if(dbs!=null&&dbs.size()>0){
					String dbname=request.getParameter("dbname");
					out.println("<h3>Databases</h3>");
					for(int i=1;i<dbs.size();i++){
						out.println("<tr><td><a href='javascript:selectDB(\""+dbs.get(i)[0]+"\")'>");
						if(dbname!=null && dbname.equals(dbs.get(i)[0])){
							out.println("<b>"+dbs.get(i)[0]+"</b></a></td></tr>");
						}else{
							out.println(dbs.get(i)[0]+"</a></td></tr>");
						}
						
					}				
				}
			%>
		</table>
		
		<table id="tableTable"  border=0>
			<%//show all tables
				if(tables!=null&&tables.size()>0){
					out.println("<h3>Tables</h3>");
					for(int i=1;i<tables.size();i++){
						out.println("<tr><td><a href='javascript:selectTable(\""+tables.get(i)[0]+"\")'>"+tables.get(i)[0]+"</a></td></tr>");
					}				
				}
			%>
		</table>		
	</td>
	<td>
		Please input sql:<br />
		<textarea style="width:99%" rows="10" id="sql" name="sql" onkeyup="doKeyup(event)" ><%
			
			String sql=request.getParameter("encodeSql");
			if(sql==null)sql="";
			try{
				sql=java.net.URLDecoder.decode(sql,"utf-8");
			}catch(Exception e){}
			if(sql!=null && sql.trim().length()>0){
				if("execute".equals(cmd)){
					db.execute(sql);
					out.print(sql);
				}
			}
		%></textarea><input type="button" class="button" value="execute" onclick="doSubmit()" />&nbsp;(ctrl+Enter)<br />
		<%
			//show results
			int[] widths=db.getColumnWidth();
			List<String[]> results=db.getResultTable();
			if(results!=null&&results.size()>0){
			%>
			<br />
			<div id="resultDiv" style="overflow:auto">
			<table id="resultTable">
				<%
					String[] row=results.get(0);
					out.print("<tr>");
					for(int i=0;i<row.length;i++){					
							out.print("<th");
							if(widths!=null){
								out.print(" width='"+(widths[i]*10)+"px' ");
							}
							out.println(">"+row[i]+"</th>");
					}
					out.println("</tr>");
					for(int j=1;j<results.size();j++){
						row=results.get(j);
						out.println("<tr>");					
						for(int i=0;i<row.length;i++){						
							out.println("<td>"+row[i]+"</td>");
						}					
						out.println("</tr>");
					}				
				%>			
			</table>			
			<br />
			</div>
			<%
			}else if(cmd.equals("execute") && sql!=null && sql.trim().length()>0){
				request.setAttribute("message","update count:"+db.getUpdateCount());
			}		


			//show message		
			message=(String)request.getAttribute("message");		
			if(message!=null&&message.length()>0){
				out.println("<div id='message'>"+message+"</div>");
			}
			
			db.close();
	
		%>
		
	</td>
</tr>

<%		
		
	}//for logined
%>

</table>
<input type="hidden" id="encodeSql" name="encodeSql" value="" />
<input type="hidden" id="cmd" name="cmd" value="" />
<input type="hidden" id="dbname" name="dbname" value="<%=request.getParameter("dbname")%>" />
<input type="hidden" id="hServerIP" name="hServerIP" value="<%=request.getParameter("hServerIP")%>" />
<input type="hidden" id="hDbType" name="hDbType" value="<%=request.getParameter("hDbType")%>" />
</form>
</body>
<style>
.button {
	display: inline-block;
	outline: none;
	cursor: pointer;
	text-align: center;
	text-decoration: none;
	font: 14px/100% Arial, Helvetica, sans-serif;
	padding: .3em 1.3em .35em;
	text-shadow: 0 1px 1px rgba(0,0,0,.3);
	-webkit-border-radius: .5em; 
	-moz-border-radius: .5em;
	border-radius: .5em;
	-webkit-box-shadow: 0 1px 2px rgba(0,0,0,.2);
	-moz-box-shadow: 0 1px 2px rgba(0,0,0,.2);
	box-shadow: 0 1px 2px rgba(0,0,0,.2);
	color: #fef4e9;
	border: solid 1px #da7c0c;
	background: #f78d1d;
	background: -webkit-gradient(linear, left top, left bottom, from(#faa51a), to(#f47a20));
	background: -moz-linear-gradient(top,  #faa51a,  #f47a20);
	margin:3px;
}
.button:hover {
	text-decoration: none;
}
.button:active {
	position: relative;
	top: 1px;
}

</style>
</html>