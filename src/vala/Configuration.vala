namespace ContainerManager {
	public class Configuration : Object {
		public static string term_exec;
		public static string default_command;
		public static string default_user;
		public static string me;
		public static string program_title;
		public static bool save;
		public static bool show_label;
		public static int wait_timeout;
		public static string container_file_extension;
		private static HashTable<string,Container> containers;

		public static void initialize() {
			Logger.entering("Configuration","initialize");
			me = "container-manager";
			program_title = "Container Manager";
			default_user = "root";
			save = false;
			show_label = true;
			wait_timeout = 10000;
			containers =  new HashTable<string,Container>(str_hash,str_equal);
			term_exec="xterm -e \"%s\"";
			default_command="/bin/sh";
			container_file_extension = "json";

			try {
				File conf_file = File.new_for_path(Environment.get_home_dir()).get_child(".local").get_child("container-manager").get_child("preferences.json");
				Json.Parser parser = new Json.Parser();
				if (conf_file.query_exists()) {
					parser.load_from_file(conf_file.get_path());
					Json.Node node = parser.get_root ();
					if (node.get_node_type () == Json.NodeType.OBJECT) {
						Json.Object root = node.get_object();
						if (root.has_member("default_user")) default_user = root.get_string_member("default_user");
						if (root.has_member("show_label")) show_label = root.get_boolean_member("show_label");
						if (root.has_member("wait_timeout")) wait_timeout = int.parse(root.get_string_member("wait_timeout"));
						if (root.has_member("term_exec")) term_exec = root.get_string_member("term_exec");
						if (root.has_member("default_command")) default_command = root.get_string_member("default_command");
					}
				}
			} catch (Error e) {
				Logger.stack_trace(e);
			}
			Logger.exiting("Configuration","initialize");
		}

		/* Container methods */
		public static Container? get_container(string key) {
			Logger.logp("Configuration","get_container",Level.FINEST,"Request container %s".printf(key));
			return (containers.contains(key))?containers.lookup(key):null;
		}

		public static void add_container(string key, Container c) {
			Logger.logp("Configuration","add_container",Level.FINEST,"Add container %s (id: %s)".printf(key, c.id));
			containers.insert(key,c);
		}

		public static List<unowned string> get_container_keys(){
			Logger.logp("Configuration","get_container_keys",Level.FINEST,"Return %u records".printf(containers.size()));
			return containers.get_keys();
		}

		/* To json and utils*/
		public static Json.Object to_json() {
			Logger.entering("Configuration","to_json");
			try {
				Json.Object root = new Json.Object();
				root.set_string_member("default_user",default_user);
				root.set_string_member("term_exec",term_exec);
				root.set_string_member("default_command",default_command);
				root.set_boolean_member("show_label",show_label);
				root.set_string_member("wait_timeout", "%d".printf(wait_timeout));
				return root;
			} catch (Error e) {
				Utils.error_message("System error","Unexpected error creating configuration json object");
				Logger.stack_trace(e);
			} finally {
				Logger.exiting("Configuration","to_json");
			}
		}

		public static void save_to_file() {
			Logger.entering("Configuration","save_to_file");
			try {
				Json.Generator generator = new Json.Generator();
				Json.Node node = new Json.Node.alloc();
				node.set_object(Configuration.to_json());
				generator.set_root(node);
				File conf_file = File.new_for_path(Environment.get_home_dir()).get_child(".local").get_child("container-manager").get_child("preferences.json");
				if (!generator.to_file(conf_file.get_path())) Utils.error_message("Error saving config file","Unable to save config file");
				else Utils.info_message("Success","Configuration saved successfully, you need to restart to apply gui changes");
			} catch (Error e) {
				Utils.error_message("System error","Unexpected error saving configuration file");
				Logger.stack_trace(e);
			} finally {
				Logger.exiting("Configuration","save_to_file");
			}
		}
	}
}