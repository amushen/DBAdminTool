package com.shennan.db;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.PrintWriter;
import java.sql.*;

/**
 * run a sql script with jdbc
 * @author shennan
 *
 */
public class MySQLScriptRunner {
	
	private final static String LINE_BREAK="\n";	//for unix file is \r
	private final static String ENCODE="UTF-8";
	private final static String[] OMIT_LINE_FLAG=new String[]{"/*"};	//which line needs to be omited.
	
	private String delimiter=";";
	private Connection conn;
	
	/*
	 *  Class.forName("org.gjt.mm.mysql.Driver").newInstance();
	 *	String url="jdbc:mysql://127.0.0.1/securityprint?characterEncoding=utf-8";
	 */
	private String driver;
	private String url;
	private String user;
	private String password;
	
	private PrintWriter out;
	
	public MySQLScriptRunner(String driver,String url,String user,String password){
		this.driver=driver;
		this.url=url;
		this.user=user;
		this.password=password;
		out=null;
	}
	
	public void setLogWriter(PrintWriter out){
		this.out=out;
	}
	
	
	public void run(String sql){
		if(out==null)out=new PrintWriter(System.out);
		if(sql==null|| sql.length()<1){
			out.println("No sql to run.");
			return;
		}
		
		getConn();
		try{
			Statement stat=this.conn.createStatement();
			String[] lines=sql.split(LINE_BREAK);
			StringBuffer one=new StringBuffer();//one statement
			boolean omit=false;
			for(String line:lines){
				//omit comment line
				omit=false;
				for(String flag:OMIT_LINE_FLAG){
					if(line.startsWith(flag)){
						omit=true;
						break;
					}
				}
				if(omit)continue;
				
				//change delimiter if necessary
				if(line.toLowerCase().startsWith("delimiter")){
					delimiter=line.substring(9).trim();
					out.println("change delimiter to "+delimiter);
					continue;
				}
				
				//add this line to sql statement
				one.append(line);				
				//judge end of a statement
				if(line.endsWith(delimiter)){
					one.delete(one.length()-delimiter.length(), one.length());
//					out.println("--------------run------------");
//					out.println(one.toString());
					try{
						stat.execute(one.toString());
						out.println("update count:"+stat.getUpdateCount());
					}catch(Exception e){
						e.printStackTrace(out);
					}
					one=null;
					one=new StringBuffer();
//					out.println("----------------end-------------");
				}							
			}
			conn.close();
		}catch(Exception e){
			e.printStackTrace();
		}
	}
	
	public void run(File file){
		if(out==null)out=new PrintWriter(System.out);
		if(file==null || !file.exists()){
			out.println("File is not exist.");
			return;
		}
		try{
			FileInputStream fis=new FileInputStream(file);
			run(fis);
		}catch(Exception e){
			e.printStackTrace();
		}
	}
	
	public void run(InputStream is){
		if(out==null)out=new PrintWriter(System.out);
		ByteArrayOutputStream bos=new ByteArrayOutputStream();
		byte[] buf=new byte[255];
		int len;
		try{
			while((len=is.read(buf,0,255))>-1){
				bos.write(buf,0,len);
			}
			is.close();
			String sql=new String(bos.toByteArray(),ENCODE);
			run(sql);
		}catch(Exception e){
			e.printStackTrace();
		}
	}
	
	private void getConn(){
		try{
		    Class.forName(this.driver).newInstance();			
			this.conn= DriverManager.getConnection(url,user,password);
		}catch(Exception e){
			e.printStackTrace();
		}
	}
	

	/**
	 * @param args
	 */
	public static void main(String[] args) {
		/*
		 *  Class.forName("org.gjt.mm.mysql.Driver").newInstance();
		 *	String url="jdbc:mysql://127.0.0.1/securityprint?characterEncoding=utf-8";
		 */
		MySQLScriptRunner runner=new MySQLScriptRunner("org.gjt.mm.mysql.Driver", "jdbc:mysql://127.0.0.1/?characterEncoding=utf-8", "root", "");
		runner.run(new File("d:\\server_db1.sql"));

	}

}
