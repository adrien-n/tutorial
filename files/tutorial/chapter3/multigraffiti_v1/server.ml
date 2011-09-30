open HTML5.M
open Common
open Lwt

module My_appl =
  Eliom_output.Eliom_appl (
    struct
      let application_name = "graffiti"
    end)

let rgb_from_string color = (* color is in format "#rrggbb" *)
  let get_color i = (float_of_string ("0x"^(String.sub color (1+2*i) 2))) /. 255. in
  try get_color 0, get_color 1, get_color 2 with | _ -> 0.,0.,0.

let launch_server_canvas () =
  let bus = Eliom_bus.create Json.t<messages> in
  
  let draw_server, image_string =
    let surface = Cairo.image_surface_create Cairo.FORMAT_ARGB32 ~width ~height in
    let ctx = Cairo.create surface in
    ((fun ((color : string), size, (x1, y1), (x2, y2)) ->

      (* Set thickness of brush *)
      Cairo.set_line_width ctx (float size) ;
      Cairo.set_line_join ctx Cairo.LINE_JOIN_ROUND ;
      Cairo.set_line_cap ctx Cairo.LINE_CAP_ROUND ;
      let red, green, blue =  rgb_from_string color in
      Cairo.set_source_rgb ctx ~red ~green ~blue ;

      Cairo.move_to ctx (float x1) (float y1) ;
      Cairo.line_to ctx (float x2) (float y2) ;
      Cairo.close_path ctx ;
      
      (* Apply the ink *)
      Cairo.stroke ctx ;
     ),
     (fun () ->
       let b = Buffer.create 10000 in
       (* Output a PNG in a string *)
       Cairo_png.surface_write_to_stream surface (Buffer.add_string b);
       Buffer.contents b
     ))
  in
  let _ = Lwt_stream.iter draw_server (Eliom_bus.stream bus) in
  bus,image_string

let graffiti_info = Hashtbl.create 0

let get_bus_image (name:string) =
  (* create a new bus and image_string function only if it did not exists *)
  try
    Hashtbl.find graffiti_info name
  with
    | Not_found ->
      let bus,image_string = launch_server_canvas () in
      Hashtbl.add graffiti_info name (bus,image_string);
      (bus,image_string)

let main_service = Eliom_services.service ~path:[""]
  ~get_params:(Eliom_parameters.unit) ()
let multigraffiti_service = Eliom_services.coservice ~fallback:main_service
  ~get_params:(Eliom_parameters.string "name") ()

let choose_drawing_form () =
  Eliom_output.Html5.get_form ~service:multigraffiti_service
    (fun (name) ->
      [p [pcdata "drawing name: ";
          Eliom_output.Html5.string_input ~input_type:`Text ~name ();
          br ();
          Eliom_output.Html5.string_input ~input_type:`Submit ~value:"Go" ()
         ]])

let graffiti_oclosure =
  unique (HTML5.M.script
            ~a:[HTML5.M.a_src (HTML5.M.uri_of_string "./graffiti_oclosure.js")
               ] (HTML5.M.pcdata ""))

let create_page content =
  (html
     (head
	(title (pcdata "Graffiti"))
        [
          HTML5.M.link ~rel:[ `Stylesheet ]
            ~href:(HTML5.M.uri_of_string"./css/graffiti.css")
            ();
          HTML5.M.link ~rel:[ `Stylesheet ]
            ~href:(HTML5.M.uri_of_string"./css/common.css")
            ();
          HTML5.M.link ~rel:[ `Stylesheet ]
            ~href:(HTML5.M.uri_of_string"./css/hsvpalette.css")
            ();
          HTML5.M.link ~rel:[ `Stylesheet ]
            ~href:(HTML5.M.uri_of_string"./css/slider.css")
            ();
          graffiti_oclosure
        ]
     )
     (body content))

let () = My_appl.register ~service:main_service
  (fun () () ->
    Lwt.return (create_page [h1 [pcdata "Welcome to Multigraffiti"];
	                     choose_drawing_form ()]))