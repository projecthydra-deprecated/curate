var ready = function(){

  showHideLicenseText();

  $("[id$=type_of_license]").change(function(e){
	showHideLicenseText();	
  });
}

function showHideLicenseText()
{
   var $license_text = $("[id$=type_of_license] option:selected").text();
   if($license_text == "Independently Licensed"){
      $("#self_deposit").hide();
      $("#independent_license").show();
    }else{
      $("#independent_license").hide();
      $("#self_deposit").show();
    }

}

$(document).ready(ready)
$(document).on('page:load', ready)
