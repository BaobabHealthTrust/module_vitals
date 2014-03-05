
function loadExtraPage(path){
  var div = document.createElement("div");
  div.id = "extraPage";
  div.style.position = "absolute";
  div.style.width = "100%";
  div.style.height = "100%";
  div.style.zIndex = "200";
  div.style.padding = "10";
  div.style.backgroundColor = "yellow";
  div.style.margin = "0px";

  document.body.appendChild(div);
  
  var frm = document.createElement("iframe");
  frm.style.width = "100%";
  frm.style.height = "100%";
  frm.style.backgroundColor = "white";
  
  frm.setAttribute("src", path)
  
  div.appendChild(frm);
  
}

function removeExtraPage(systolic, diastolic, pulse){

  __$("touchscreenInput" + tstCurrentPage).value = systolic;

  if(typeof(systolic) != "undefined"){
    if(__$("systolic_pressure")){
      __$("systolic_pressure").value = systolic;
    }
  }
  
  if(typeof(systolic) != "undefined"){
    if(__$("diastolic_pressure")){
      __$("diastolic_pressure").value = diastolic;
    }
  }
  
  if(typeof(pulse) != "undefined"){
    if(__$("pulse_rate")){
      __$("pulse_rate").value = pulse;
    }
  }    
  
}

