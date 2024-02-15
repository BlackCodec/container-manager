namespace ContainerManager {

	public class Main {
		
		/* Container methods */
		public static bool parse_container_configs() {
			Logger.entering("Main","parse_container_configs");
			try {
				File container_folder = File.new_for_path(Environment.get_home_dir()).get_child(".local").get_child("container-manager").get_child("stored");
				if (container_folder.query_exists()) {
					GLib.Dir dir = Dir.open(container_folder.get_path(),0);
					string fname = null;
					while ((fname = dir.read_name()) != null) {
						Logger.log(Level.FINE, "Found filename: {0}", new string[] {fname});
						if (fname.has_suffix(".%s".printf(Configuration.container_file_extension))) {
							fname=fname.substring(0,fname.length-(Configuration.container_file_extension.length+1));
							Logger.log(Level.FINE, "Loaded file id: {0}", new string[] {fname});
							Container c = Utils.parse_container_file(fname);
							Configuration.add_container(fname,c);
						}
					}
				}
				return true;
			} catch (Error e) {
				Utils.error_message("System error", "Error processing container configuration files");
				Logger.stack_trace(e);
			} finally {
				Logger.exiting("Main","parse_configs");
			}
			return false;
		}

		/* gui or command line mode */
		public static int process_command_line(string[] params) {
			Logger.entering("Main","process_command_line");
			if (params.length >= 1) {
				if (process_common_switch(params)) {
					Logger.finest("Arguments: %d".printf(params.length));
					ContainerManager.Container container = new ContainerManager.Container();
					Logger.finest("Loaded default container object, start parsing arguments ...");
					foreach (string arg in params) {
						Logger.log(Level.FINEST, "Parse argument: {0}", new string[] {arg});
						string key = arg;
						string value="";
						if (key.contains("=")) {
							key=arg.split("=",2)[0];
							value=arg.split("=",2)[1];
							Logger.log(Level.FINEST, "Key: {0} - Value: {1}", new string[] {key,value});
						}
						switch (key) {
							case "--id":
								Logger.log(Level.INFO,"Create a container with id {0}", new string[] {value});
								container = new ContainerManager.Container.with_id(value);
								container.load();
								break;
							case "--name":
								container.set_name(value);
								break;
							case "--username":
								container.set_username(value);
								break;
							case "--cmd":
								container.set_start_command(value);
								break;
							case "--image":
								container.set_image(value,null);
								break;
							case "--mount":
								container.add_mount(value);
								break;
							case "--background":
								container.enable_background();
								break;
							case "--persist":
								container.enable_persistence();
								break;
							case "--term":
							case "--level":
							case "--save":
							case "--help":
								break;
							default:
								Logger.log(Level.SEVERE,"Unrecognized argument: {0}", new string[] {arg});
								printHelp();
								return 1;
						}
					}
					Logger.finest("Parsed all parameters");
					try {
						string exec_cmd = container.cmd();
						Logger.log(Level.FINEST, "Command to execute:\n  {0}", new string[] { exec_cmd } );
						if (Configuration.save) Utils.save_container_file(container);
							Logger.log(Level.FINEST,"Launch command: {0}", new string[] {Configuration.term_exec.printf(exec_cmd)});
							int run = Posix.system(Configuration.term_exec.printf(exec_cmd));
							Logger.log(Level.FINEST,"Command execution status: {0}", new string[] {"%d".printf(run)});
							return run;
					} catch (Error err) {
						Logger.stack_trace(err);
						return 2;
					}
				} else
					return 0;
			} else {
				printHelp();
				return 1;
			}
		}

		public static int show_gui(string[] args) {
			Logger.entering("Main","show_gui");
			try {
				if (process_common_switch(args)) {
					if (parse_container_configs()) {
						Gtk.init(ref args);
						Gtk.Window window = new MainWindow();
						window.destroy.connect(Gtk.main_quit);
						window.show_all();
						Gtk.main ();
						return 0;
					} else Logger.severe("Error during configuration parse");
				} else Logger.severe("Error processing common switch");
			} finally {
				Logger.exiting("Main","show_gui");
			}
			return 1;
		} 

		public static bool process_common_switch(string[] params) {
			Logger.entering("Main","process_common_switch");
			foreach (string arg in params) {
				Logger.log(Level.FINEST, "Parse argument: {0}", new string[] {arg});
				string key = arg;
				string value="";
				if (key.contains("=")) {
					key=arg.split("=",2)[0];
					value=arg.split("=",2)[1];
					Logger.log(Level.FINEST, "Key: {0} - Value: {1}", new string[] {key,value});
				}
				switch (key) {
					case "--term":
						Configuration.term_exec=value;
						break;
					case "--level":
						Logger.set_level(Level.get(value));
						break;
					case "--save":
						Configuration.save = true;
						break;
					case "--help":
						printHelp();
						return false;
					default:
						break;
				}
			}
			Logger.exiting("Main","process_common_switch");
			return true;
		}

		/* Help message */
		public static void printHelp() {
			string help_msg="Usage:\n%s".printf(Configuration.me);
			help_msg += " [--id=<id>] --name=<name_to_use> [--cmd=<command_to_execute>] \n";
			help_msg += " [--username=<username>] [--image=<specify_image_name>] [--mount=<mount_point>] \n";
			help_msg += " [--persist] [--background] [--term=<terminal_cmd>] \n";
			help_msg += " [--level=<SEVERE,WARNING,INFO,FINE,FINER,FINEST,OFF,ALL>]\n\n";
			help_msg += "The option --mount can be used more times for multiple mount points.\n";
			help_msg += "If username is not specified the value 'root' will be used.\n";
			help_msg += "If not specified container name and image use the same value.\n";
			help_msg += "If not specified the container is not persistent, this means it will be destroyed and remove after exiting from container.\n";
			help_msg += "If background option is specified the container will be destroyed after the startup command exits.\n";
			help_msg += "If id is specified it must be the first parameter, otherwhise the configurations could be override.\n";
			help_msg += "If log level was not specified is assumed to be 'OFF' for command line launch and 'ALL' for graphical interface mode.\n";
			stdout.printf(help_msg);
		}

		public static int main(string[] args) {
			Logger.set_level(Level.SEVERE);
			Logger.entering("Main","main");
			Configuration.initialize();
			Configuration.me = args[0];
			string[] params = args[1:args.length];
			if (params.length >= 1) {
				Logger.set_level(Level.OFF);
				return process_command_line(params);
			} else {
				Logger.set_level(Level.ALL);
				return show_gui(params);
			}
		}
	}
}
