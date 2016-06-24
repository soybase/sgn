/*jslint browser: true, devel: true */

/**

=head1 UploadTrial.js

Dialogs for uploading trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {


    function upload_trial_file() {
        var uploadFile = $("#trial_uploaded_file").val();
        $('#upload_trial_form').attr("action", "/ajax/trial/upload_trial_file");
        if (uploadFile === '') {
	    alert("Please select a file");
	    return;
        }
        $("#upload_trial_form").submit();
    }

    function open_upload_trial_dialog() {
	$('#upload_trial_dialog').modal("show");
	//add a blank line to design method select dropdown that dissappears when dropdown is opened
	$("#trial_upload_design_method").prepend("<option value=''></option>").val('');
	$("#trial_upload_design_method").one('mousedown', function () {
            $("option:first", this).remove();
            $("#trial_design_more_info").show();
	    //trigger design method change events in case the first one is selected after removal of the first blank select item
	    $("#trial_upload_design_method").change();
	});

	//reset previous selections
	$("#trial_upload_design_method").change();
    }

    $('#upload_trial_link').click(function () {
        open_upload_trial_dialog();
    });

    $('#upload_trial_submit').click(function () {
        upload_trial_file();
    });

//    $("#upload_trial_dialog").dialog({
//	autoOpen: false,
//	modal: true,
//	autoResize:true,
//        width: 500,
//        position: ['top', 75],
//	buttons: {
//            "Cancel": function () {
//                $('#upload_trial_dialog').dialog("close");
//            },
//	    "Ok": function () {
//		upload_trial_file();
//	    },
//	}
//    });

    $("#trial_upload_spreadsheet_format_info").click( function () {
	$('#upload_trial_dialog').modal("hide");
	$("#trial_upload_spreadsheet_info_dialog" ).modal("show");
    });

//    $("#trial_upload_spreadsheet_info_dialog").dialog( {
//	autoOpen: false,
//	buttons: { "OK" :  function() { $("#trial_upload_spreadsheet_info_dialog").dialog("close"); },},
//	modal: true,
//	width: 900,
//	autoResize:true,
//    });

//    $( "#trial_upload_success_dialog_message" ).dialog({
//	autoOpen: false,
//	modal: true,
//	buttons: {
//            Ok: { id: "dismiss_trial_upload_dialog",
//                  click: function() {
//		      //$("#upload_trial_form").dialog("close");
//		      //$( this ).dialog( "close" );
//		      location.reload();
//                  },
//                  text: "OK"
//                }
//        }
//    });

    $('#upload_trial_form').iframePostForm({
	json: true,
	post: function () {
            var uploadedTrialLayoutFile = $("#trial_uploaded_file").val();
	    $('#working_modal').modal("show");
            if (uploadedTrialLayoutFile === '') {
		$('#working_modal').modal("hide");
		alert("No file selected");
            }
	},
    complete: function (response) {
        console.log(response);

        $('#working_modal').modal("hide");
        if (response.error_string) {
            $("#upload_trial_error_display tbody").html('');

            if (response.missing_accessions) {
                var missing_accessions_html = "<div class='well well-sm'><h3>Add the missing accessions to a list</h3><div id='upload_trial_missing_accessions' style='display:none'></div><div id='upload_trial_add_missing_accessions'></div><hr><h4>Go to <a href='/breeders/accessions'>Manage Accessions</a> to add these new accessions.</h4></div><br/>";
                $("#upload_trial_add_missing_accessions_html").html(missing_accessions_html);

                var missing_accessions_vals = '';
                for(var i=0; i<response.missing_accessions.length; i++) {
                    missing_accessions_vals = missing_accessions_vals + response.missing_accessions[i] + '\n';
                }
                $("#upload_trial_missing_accessions").html(missing_accessions_vals);
                addToListMenu('upload_trial_add_missing_accessions', 'upload_trial_missing_accessions');
            }

            $("#upload_trial_error_display tbody").append(response.error_string);
            $('#upload_trial_dialog').modal("hide");
            $('#upload_trial_error_display').modal("show");

		//$(function () {
                //    $("#upload_trial_error_display").dialog({
		//	modal: true,
		//	autoResize:true,
		//	width: 650,
		//	position: ['top', 250],
		//	title: "Errors in uploaded file",
		//	buttons: {
                //            Ok: function () {
		//		$(this).dialog("close");
                //            }
		//	}
                //    });
		//});
		return;
            }
            if (response.error) {
		console.log(response);
		alert(response.error);
		return;
            }
            if (response.success) {
		console.log(response);
		//alert("uploadTrial got success response" + response.success);
		$('#trial_upload_success_dialog_message').modal("show");
		//alert("File uploaded successfully");
            }
	}
    });

});
