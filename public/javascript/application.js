var ArticleSemanticizer = (function($, window, document) {

  var _private = {

    data_sources: { scientific : {}, vernacular : {} },

    init: function() {
      this.bloodhound();
      this.typeahead();
    },
    bloodhound: function() {
      this.data_sources.scientific = this.create_bloodhound('scientific');
      this.data_sources.vernacular = this.create_bloodhound('vernacular');
      this.data_sources.scientific.initialize();
      this.data_sources.vernacular.initialize();
    },
    create_bloodhound: function(type) {
      return new Bloodhound({
        datumTokenizer : function(d) { return Bloodhound.tokenizers.whitespace(d.name); },
        queryTokenizer : Bloodhound.tokenizers.whitespace,
        limit : 10,
        remote : {
          url : '/'+type+'.json?q=%QUERY',
          filter : function(r) { return $.map(r, function(v) { return { 'name' : v }; }); }
        }
      });
    },
    typeahead: function(){
      $('.typeahead').typeahead({
          minLength: 3,
          highlight: true
        },
        {
          name: 'scientific',
          source : this.data_sources.scientific.ttAdapter(),
          displayKey : 'name',
          templates : {
            header: '<h3 class="taxontype-name">Scientific</h3>'
          }
        },
        {
          name: 'vernacular',
          source: this.data_sources.vernacular.ttAdapter(),
          displayKey : 'name',
          templates : {
            header: '<h3 class="taxontype-name">Vernacular</h3>'
          }
        }).on('typeahead:selected', this.dropdown_selected).focus().select();
    },
    dropdown_selected: function(){
      window.location.href = '/?q='+encodeURIComponent($(this).val());
    },
  };

  return {
    init: function() {
      _private.init();
    }
  };

}(jQuery, window, document));

ArticleSemanticizer.places = (function($, window, document) {
  var _private = {
    locales: [],
    overlays: [],
    map: {},
    darwing_manager: {},
    canvas_id: '#map-canvas',
    init: function() {
      this.load_gmap_script();
    },
    load_gmap_script: function() {
      var script = document.createElement('script');
      script.type = 'text/javascript';
      script.src = 'https://maps.googleapis.com/maps/api/js?libraries=drawing&sensor=false&callback=ArticleSemanticizer.places.create_gmap';
      document.body.appendChild(script);
    },
    activate_reset: function() {
      var self = this;
      $('#reset_form').on('click', function() { self.clear_overlays(); });
    },
    create_gmap: function() {
      var mapOptions = {
        zoom: 1,
        center: new google.maps.LatLng(35, 0)
      };
      this.map = new google.maps.Map($(this.canvas_id)[0], mapOptions);
      google.maps.Polygon.prototype.getBounds = function(){
        var bounds = new google.maps.LatLngBounds();
        this.getPath().forEach(function(element,index){bounds.extend(element);});
        return bounds;
      };
    },
    create_overlay: function() {
      this.map.setZoom(2);
      this.map.setCenter(new google.maps.LatLng(65, -40));
      var geo = this.getParameterByName('geo');

      switch(geo) {
        case 'circle':
          var coord = this.getParameterByName("c").split(","),
              center = new google.maps.LatLng(coord[0], coord[1]),
              options = {
                center : center,
                radius : this.getParameterByName("r")*1000
              },
              circle = new google.maps.Circle(options);

          circle.setMap(this.map);
          this.overlays.push(circle);
          this.map.fitBounds(circle.getBounds());
        break;

        case 'rectangle':
          var bbox = this.getParameterByName("b").split(","),
              bounds = new google.maps.LatLngBounds(
                new google.maps.LatLng(bbox[0], bbox[1]),
                new google.maps.LatLng(bbox[2], bbox[3])
              ),
              rectangle = new google.maps.Rectangle({
                bounds: bounds
              });

          rectangle.setMap(this.map);
          this.overlays.push(rectangle);
          this.map.fitBounds(rectangle.getBounds());
        break;

        case 'polygon':
          var vertices = JSON.parse(this.getParameterByName("p")),
              paths = [];
              $.each(vertices, function() {
                paths.push(new google.maps.LatLng(this[0], this[1]));
              });
          var polygon = new google.maps.Polygon({
                paths: paths
              });

          polygon.setMap(this.map);
          this.overlays.push(polygon);
          this.map.fitBounds(polygon.getBounds());
        break;
      }
    },
    clear_overlays: function() {
      $.each(this.overlays, function() {
        if(this.hasOwnProperty('overlay')) {
          this.overlay.setMap(null);
        } else {
          this.setMap(null);
        }
      });

      this.overlays = [];

      $('#geo_type').val('');
      $('#geo_center').val('');
      $('#geo_radius').val('');
      $('#geo_bounds').val('');
      $('#geo_polygon').val('');
    },
    getParameterByName: function(name) {
        name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]");
        var regex = new RegExp("[\\?&]" + name + "=([^&#]*)"),
            results = regex.exec(location.search);
        return results == null ? "" : decodeURIComponent(results[1].replace(/\+/g, " "));
    },
    create_drawing: function() {
      var self = this;
      this.drawing_manager = new google.maps.drawing.DrawingManager({
        drawingControl: true,
        drawingControlOptions: {
          position: google.maps.ControlPosition.LEFT_CENTER,
          drawingModes: [
            google.maps.drawing.OverlayType.CIRCLE,
            google.maps.drawing.OverlayType.RECTANGLE,
            google.maps.drawing.OverlayType.POLYGON
          ]
        }
      });
      this.drawing_manager.setMap(this.map);
      google.maps.event.addListener(this.drawing_manager, 'drawingmode_changed', function() {
        if(self.overlays.length > 0 && self.drawing_manager.drawingMode) {
          self.clear_overlays();
        } 
      });
      google.maps.event.addListener(this.drawing_manager, "overlaycomplete", function(e) {
        self.drawing_done(e, self);
      });
    },
    drawing_done: function(e,scope) {
      scope.drawing_manager.setOptions({ drawingMode: null });
      scope.overlays.push(e);
      $('#geo_type').val(e.type);
      switch(e.type) {
        case 'circle':
          var center = e.overlay.getCenter().toUrlValue(),
              radius = e.overlay.radius/1000;
          $('#geo_center').val(center);
          $('#geo_radius').val(radius);
        break;

        case 'rectangle':
          var bounds = e.overlay.getBounds().toUrlValue();
          $('#geo_bounds').val(bounds);
        break;

        case 'polygon':
          var polygon = "[" + e.overlay.getPath().getArray().toString().replace(/\(/g,"[").replace(/\)/g, "]") + "]";
          $('#geo_polygon').val(polygon);
        break;
      }
    },
    load_markers: function() {
      var self = this;
      $.each(this.locales, function() {
        if(this.location) {
          var coords = this.location.split(","),
              infowindow = new google.maps.InfoWindow({ content: this.name }),
              marker = new google.maps.Marker({
                position: new google.maps.LatLng(coords[0],coords[1]),
                map: self.map,
                title: this.name
              });

          google.maps.event.addListener(marker, 'click', function() {
            infowindow.open(self.map,marker);
          });
        }
      });
    }
  };

  return {
    init: function(locales) {
      _private.locales = locales || [];
      _private.init();
    },
    create_gmap: function() {
      _private.create_gmap();
      if(_private.locales.length > 0) {
        _private.load_markers();
      } else {
        _private.create_overlay();
        _private.create_drawing();
      }
      _private.activate_reset();
    },
    clear_overlays: function() {
      _private.clear_overlays();
    }
  };

}(jQuery, window, document));