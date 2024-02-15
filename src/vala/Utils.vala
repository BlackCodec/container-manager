namespace ContainerManager {

	public class Utils {
		private static string userid = "";
		private static string groupid = "";
		private static string username = "";

		
		/* Process and command line methods */
		public static string exec(string command) {
			string ret_out = Utils.exec_multi(command);
			return (ret_out != null)?ret_out.replace("\n",""):"";
		}

		public static string exec_multi(string command) {
			string output;
			Process.spawn_command_line_sync(command, out output);
			return (output != null)?output:"";
		}

		public static int execute(string command) { return Posix.system(command); }
		
		public static string get_group_id() { 
			if (Utils.groupid == "" || Utils.groupid == null ) Utils.groupid = Utils.exec("id -g");
			Logger.logp("Utils","get_group_id",Level.FINEST,"Group id %s".printf(Utils.groupid));
			return (Utils.groupid == "")?"0":Utils.groupid;
		}
		
		public static string get_user_id() { 
			if (Utils.userid == "" || Utils.userid == null) Utils.userid = Utils.exec("id -u");
			Logger.logp("Utils","get_user_id",Level.FINEST,"User id %s".printf(Utils.userid));
			return (Utils.userid == "")?"0":Utils.userid;
		}

		public static string get_username() {
			if (Utils.username == "" || Utils.username == null) Utils.username = GLib.Environment.get_user_name();
			Logger.logp("Utils","get_username",Level.FINEST,"Username %s".printf(Utils.username));
			return Utils.username;
		}

		/* Dialog methods */
		public static bool yesno(string primary_markup, string? secondary_markup = null, Gtk.Window? parent = null) {
			Gtk.MessageDialog dialog = new Gtk.MessageDialog.with_markup(parent,Gtk.DialogFlags.MODAL,Gtk.MessageType.QUESTION,Gtk.ButtonsType.OK_CANCEL,primary_markup);
			dialog.format_secondary_markup(secondary_markup);
			Gtk.ResponseType response = (Gtk.ResponseType) dialog.run();
			dialog.destroy();
			return (response == Gtk.ResponseType.OK);
		}

		public static void error(string primary_markup, string? secondary_markup = null, Gtk.Window? parent = null) {
			Gtk.MessageDialog dialog = new Gtk.MessageDialog.with_markup(parent,Gtk.DialogFlags.MODAL,Gtk.MessageType.ERROR,Gtk.ButtonsType.CLOSE,primary_markup);
			dialog.format_secondary_markup(secondary_markup);
			dialog.run();
			dialog.destroy();
		}
		
		public static void info(string primary_markup, string? secondary_markup = null, Gtk.Window? parent = null) {
			Gtk.MessageDialog dialog = new Gtk.MessageDialog.with_markup(parent,Gtk.DialogFlags.MODAL,Gtk.MessageType.INFO,Gtk.ButtonsType.CLOSE,primary_markup);
			dialog.format_secondary_markup(secondary_markup);
			dialog.run();
			dialog.destroy();
		}
		
		public static void error_message(string title, string body) { Utils.error(title,body,null); }
		
		public static void info_message(string title, string body) { Utils.info(title,body,null); }

		/* File management methods */
		public static bool delete_container_file(string id) {
			Logger.entering("Utils","delete_container_file");
			try {
				Logger.log(Level.INFO,"Delete container file with id {0}", new string[] { id });
				File configFile = File.new_for_path(Environment.get_home_dir()).get_child(".local").get_child("container-manager")
					.get_child("stored").get_child("%s.%s".printf(id,Configuration.container_file_extension));
				return (configFile.query_exists() && (Utils.execute("rm -f \"%s\"".printf(configFile.get_path())) == 0));
			} catch (Error e) {
				Utils.error_message("System error","Unexpected error during delete of file with id %s".printf(id));
				Logger.stack_trace(e);
			} finally {
				Logger.exiting("Utils","delete_container_file");
			}
			return false;
		}
		
		public static Container parse_container_file(string id) {
			Logger.entering("Utils","parse_container_file");
			Logger.log(Level.INFO, "Load id {0}", new string[] {id});
			Container c = new Container.with_id(id);
			File container_folder = File.new_for_path(Environment.get_home_dir()).get_child(".local").get_child("container-manager").get_child("stored");
			string file = "%s/%s.%s".printf(container_folder.get_path(),id,Configuration.container_file_extension);
			Logger.log(Level.INFO,"File to parse: {0}", new string[] {file});
			try {
				Json.Parser parser = new Json.Parser();
				parser.load_from_file(file);
				Logger.finest("File loaded from parser, get root node");
				Json.Node node = parser.get_root ();
				if (node.get_node_type () == Json.NodeType.OBJECT) {
					Json.Object root = node.get_object();
					if (root.has_member("options")) {
						Logger.finest("Parse key options");
						Json.Object options = root.get_object_member("options");
						foreach (unowned string name in options.get_members ()) {
							Json.Object item = options.get_member(name).get_object();
							string key = name;
							ContainerOptionKeys? cokey = ContainerOptionKeys.get(name);
							if (cokey != null) {
								key = cokey.value();
								Logger.log(Level.FINEST,"Key value={0}",new string[] {key});
							}
							ContainerOption coobj = ContainerOption.from_json(item);
							Logger.log(Level.FINEST,"Add option with key {0} = {1}",new string[] {key, coobj.cmd()});
							c.options.insert(key,coobj);
						}
					}
					if (root.has_member("mounts")) {
						Logger.finest("Parse key mounts");
						Json.Array mounts = root.get_array_member("mounts");
						foreach (unowned Json.Node mount in mounts.get_elements()) {
							string m_rule = mount.get_string();
							c.add_mount(m_rule);
							Logger.log(Level.FINEST,"Add mounts {0}",new string[] {m_rule});
						}
						Logger.finest("Added %s mounts".printf(c.mounts.length().to_string()));
					}
					if (root.has_member("cmd")) {
						Logger.finest("Parse key cmd");
						c.set_start_command(root.get_string_member("cmd"));
					}
					if (root.has_member("image")) {
						Logger.finest("Parse key image");
						c.set_image(root.get_string_member("image"),null);
					}
				}
			} catch (Error e) {
				Utils.error_message("Error parsing container file","Error parsing container file, check log for details");
				Logger.stack_trace(e);
			} finally {
				Logger.exiting("Utils","parse_container_file");
			}
			return c;
		}
		
		public static bool save_container_file(Container c) {
			Logger.entering("Utils","save_container_file");
			try {
				File container_folder = File.new_for_path(Environment.get_home_dir()).get_child(".local").get_child("container-manager").get_child("stored");
				if (!container_folder.query_exists() && !container_folder.make_directory_with_parents()) {
					Utils.error_message("Error creating setup folder","Unable to create setup folder: %s".printf(container_folder.get_path()));
					return false;
				}
				if (c.id == "-1") {
					int i = 0;
					bool found = true;
					while (found) {
						i++;
						string filename = "%s/%d.%s".printf(container_folder.get_path(),i, Configuration.container_file_extension);
						File file_obj = File.new_for_path(filename);
						if (!file_obj.query_exists()) {
							Logger.log(Level.FINE,"Set container id: {0}", new string[] { "%d".printf(i)} );
							c.id="%d".printf(i);
							found = false;
							FileOutputStream os = file_obj.create (FileCreateFlags.NONE);
							os.write ("created\n".data);
						}
					}
				}
				string file = "%s/%s.%s".printf(container_folder.get_path(),c.id,Configuration.container_file_extension);
				Json.Generator generator = new Json.Generator();
				Json.Node node = new Json.Node.alloc();
				node.set_object(c.to_json());
				generator.set_root(node);
				if (!generator.to_file(file)) Utils.error_message("Error saving file","Unable to save container configuration file with name %s".printf(file));
				else return true;
			} catch (Error e) {
				Utils.error_message("System error","Unexpected error during saving container config file.");
				Logger.stack_trace(e);
			} finally {
				Logger.exiting("Utils","save_container_file");
			}
			return false;
		}
	}
}