<?php
    $error = "";        //error holder
    if(isset($_POST['createarchive'])){
        $post = $_POST;     
        $file_folder = "archives/";    // folder to load files
        if(isset($post['files']) and count($post['files']) > 0){    // Checking files are selected
//            $archive_name = time().".tar.xz";          // Zip name
            $archive_name = date(Ymd).".tar.xz";          // Zip name
            foreach($post['files'] as $file){               
                if(count($post['files']) == 1){
                     $toArchive_list = $file;          // Adding files into zip
                } else {
                     $toArchive_list .= ${file}." ";          // Adding files into zip
		}
            }
            $cmd = "tar -I xz -cvf $file_folder/$archive_name $toArchive_list";
            ob_start();
            $last_line = system($cmd, $retval);
            $output = ob_get_clean();
            $cmd = "rm -r $toArchive_list";
            ob_start();
            $last_line = system($cmd, $retval);
            $output = ob_get_clean();
//            if(file_exists($file_folder/$archive_name)){
//                header('Content-type: application/zip');
//                header('Content-Disposition: attachment; filename="'.${file_folder}/${archive_name}.'"');
//                readfile(${file_folder}/${archive_name});
//                unlink(${file_folder}/${archive_name});
//            }

        } else
            $error .= "* Please select position to archive<br/>";
    }
?>

<! --$last_line = system('ls', $retval); -->

<!DOCTYPE html>
<HTML LANG="en">
<HEAD>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=utf-8" />
<TITLE>CATMAN Archive entries SWITCHE.LOCAL.PL</TITLE>
</HEAD>
<BODY>
<CENTER><H1>Arhives for selection</H1></CENTER>
<FORM NAME="archive" METHOD="post">
<?php if(!empty($error)) { ?>
<P STYLE="border:#C10000 1px solid; background-color:#FFA8A8; color:#B00000;padding:8px; width:588px; margin:0 auto 10px;"><?php echo $error; ?></P>
<?php } ?>
<TABLE WIDTH="600" BORDER="1" ALIGN="center" CELLPADDING="10" CELLSPACING="0" STYLE="border-collapse:collapse; border:#ccc 1px solid;">
  <TR>
    <TD WIDTH="33" ALIGN="center">*</td>
    <TD WIDTH="117" ALIGN="center">File Type</td>
    <TD WIDTH="382">File Name</td>
  </TR>

<?php
$src_dir="actionlogs";
$true=0;
if ($handle = opendir("$src_dir/")) {
    while (false !== ($entry = readdir($handle))) {
	$ext = explode(".", $entry);
        switch ($ext[1]) {
	case "php":
	case "html":
	case "htm":
	case "swp":
              break;
	default:
              if ( $entry != "." && $entry != ".." && !is_dir("$src_dir/$entry" ) ) {
		$dirFiles[] = $entry;
		$true=1;
              }
        }
//        echo "DEBUG [$src_dir/$entry] &nbsp; [$ext[1]]<BR>\n";
    }
    closedir($handle);
//    sort($dirFiles);
    if ($true) {
    natsort($dirFiles);
    foreach($dirFiles as $file) {
        echo "<TR><TD ALIGN=\"center\"><INPUT TYPE=\"checkbox\" NAME=\"files[]\" VALUE=\"${src_dir}/$file\"></TD>\n";
        echo "<TD ALIGN=\"center\"><IMG SRC=\"/icons/small/text.png\" TITLE=\"Document\" WIDTH=\"16\" HEIGHT=\"16\"></TD>\n";
        echo "<TD><A TARGET=\"_blank\" HREF=\"${src_dir}/${file}\">$file</A></TD></TR>\n";
    }
    }
}
?>
<TR><TD COLSPAN="3" ALIGN="center">
	<INPUT TYPE="submit" NAME="createarchive" STYLE="border:0px; background-color:#800040; color:#FFFFFF; padding:10px; cursor:pointer; font-weight:bold; border-radius:5px;" VALUE="Archive selected">&nbsp;<INPUT TYPE="reset" NAME="reset" STYLE="border:0px; background-color:#D3D3D3; color:#000000; font-weight:bold; padding:10px; cursor:pointer; border-radius:5px;" VALUE="Reset">&nbsp;<A HREF="http://switche.local.pl" STYLE="text-decoration: none; border:0px; background-color:#D3D3D3; color:#000; font-weight:normal; padding:9px; cursor:pointer; border-radius:5px;">Return</A>
</TD></TR>
</TABLE>
</FORM>
<P ALIGN="center"><I><B>CatMan</B>&trade; ver. 1.7.3.2 build 20200406</I><BR>
&copy;&reg;<I>2017-2020</I> Pawel Trepka</P>
</BODY>
</HTML>

