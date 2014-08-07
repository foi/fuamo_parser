$(document).ready(function() { 
  var building_count = $('h3').size();
  var building_ready = $('h3 > .glyphicon-ok').size();
  $("span#building-pdf").html(building_ready + " из " + building_count);
  var department_count = $('h4#dep').size();
  var department_ready = $('h4#dep > .glyphicon-ok').size();
  $("span#department-pdf").html(department_ready + " из " + department_count);
  var room_count = $('h4#room').size();
  var room_ready = $('h4#room > .glyphicon-ok').size();
  $("span#rooms-pdf").html(room_ready + " из " + room_count);
})