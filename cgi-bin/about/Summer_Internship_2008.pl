use strict;
use CXGN::Page;
my $page=CXGN::Page->new('Summer_Internship_2008.html','html2pl converter');
$page->header('2008 Summer Interns');
print<<END_HEREDOC;

<div class="boxbgcolor2">

<h2 align="center">2008 Bioinformatics Summer Interns</h2>

<p>Four students participated in our Bioinformatics Summer Internship Program offered through the NSF-funded project entitled Sequence and annotation of the tomato euchromatin:  a framework for Solanceae comparative biology (http://www.sgn.cornell.edu/about/tomato_project_overview.pl). The internships provide opportunities in bioinformatics training for undergraduates and high school students.  Below are photographs of the 2008 summer interns along with descriptions of their projects.  For information on the internships, contact Dr. Joyce Van Eck (jv27\@cornell.edu).</p>

<br />

<table summary="">

<tr><td><strong>Carolyn Ochoa</strong></td></tr>
<tr>
<td><img src="/static_content/sgn_photos/interns_2008/cochoa.jpg" /></td>
<td>Carolyn is a recent graduate of Ramapo College. During her internship at SGN, she analyzed the promoter regions of tomato contigs for transcription factor binding motifs, grouped the tomato contigs into their corresponding biochemical pathways according to the LycoCyc database, and used MEME to predict motifs and compare them to known motifs found in the PlantCARE database. She then performed the same analyses on Arabidopsis promoters and compared results.</td>
</tr>

<tr><td><br /><strong>Mallory Freeberg</strong></td></tr>
<tr>
<td><img src="/static_content/sgn_photos/interns_2008/mfreeberg.jpg" /></td>
<td>Mallory is an undergraduate student at Saint Vincent College. During her internship at SGN, she wrote a motif finder to find commonly occurring sequence motifs within the untranslated regions (UTRs) of Solanaceae unigenes. After finding possible motifs, she compared these sequences to known coding sequences, vector sequences, etc, in order to determine whether or not they are truly UTRs. The goal was to create a set of motifs that are biologically significant and which should be further studied in the laboratory to find out how they function.</td>
</tr>

<tr><td><br /><strong>Aileen Tolentino
</strong></td></tr>
<tr>
<td><img src="/static_content/sgn_photos/interns_2008/atolentino.jpg" /></td>
<td>Aileen is a recent graduate of Ramapo College. During her internship with Dr. Zhangjun Fei, she used a combination of perl scripts and existing bioinformatics programs to search for putative miRNA sequences within the tomato genome and created and populated small RNA and miRNA tables within the Tomato Functional Genomics Database.</td>
</tr>

<tr><td><br /><strong>Viktor Vassilev</strong></td></tr>
<tr>
<td><img src="/static_content/sgn_photos/interns_2008/vvasilev.jpg" /></td>
<td>Viktor is an undergraduate student at Ramapo College. During his internship with Dr. Zhangjun Fei, he identified SNPs from ESTs generated by 454 sequencing technology and created an EST unigene build.</td>
</tr>

<tr><td>&nbsp;<br /></td></tr>

<tr><td>&nbsp;<br /></td></tr>

</table>

</div>
END_HEREDOC
$page->footer();
