namespace ContainerManager {

	public enum ContainerOptionKeys {
		INTERACTIVE, NAME, PRIVILEGED, NO_PERSISTENCE, DETACHED,
		RUNTIME, NETWORK, USER_NAMESPACE, GROUP_ADD, USER,
		ULIMIT, ENV_DISPLAY, ENV_SHELL, ANNOTATION,
		SECURITY_LABEL, MOUNT_PTS, TTY, PID;

		public string value() { return this.to_string().down().replace("container_manager_container_option_keys_",""); }

		public static ContainerOptionKeys[] values() {
			return { INTERACTIVE, NAME, PRIVILEGED, NO_PERSISTENCE, DETACHED, RUNTIME,
				NETWORK, USER_NAMESPACE, GROUP_ADD, USER, ULIMIT, ENV_DISPLAY,
				ENV_SHELL, ANNOTATION, SECURITY_LABEL, MOUNT_PTS, TTY, PID };
		}

		public static ContainerOptionKeys? get(string name) {
			foreach (ContainerOptionKeys cokey in ContainerOptionKeys.values())
				if (cokey.value() == name) return cokey;
			return null;
		}
	}

	public class ContainerOption {

		private string value=null;
		private string attribute=null;
		private bool raw = true;

		public ContainerOption(string value) { this.value = value; }
		public ContainerOption.from_value(string value) { this(value); this.raw = false; }
		public ContainerOption.with_name(string name, string value) { this.from_value(value); this.attribute = name; }
		public ContainerOption.empty() { this.value = ""; this.raw = true; }

		public string get_value() { return this.value; }
		public string cmd() { 
			if (this.raw) return this.value;
			if (this.attribute != null) return "--%s=%s".printf(this.attribute,this.value);
			return "--%s".printf(this.value); 
		}

		public bool is_raw() { return this.raw; }

		public static ContainerOption from_json(Json.Object data) throws InvalidObject {
			if (data.has_member("value")) {
				string l_value = data.get_string_member("value");
				if (data.has_member("raw") && data.get_boolean_member("raw")) return new ContainerOption(l_value);
				if (data.has_member("name")) {
					string l_name = data.get_string_member("name");
					return new ContainerOption.with_name(l_name,l_value);
				}
				return new ContainerOption.from_value(l_value);
			} else throw new InvalidObject.message("ContainerOption");
		}

		public Json.Object to_json() {
			Json.Object j_opt = new Json.Object();
			j_opt.set_boolean_member("raw",this.raw);
			if (this.attribute != null) j_opt.set_string_member("name",this.attribute);
			if (this.value != null) j_opt.set_string_member("value",this.value);
			return j_opt;
		}

		public static ContainerOption? get_predefined(ContainerOptionKeys key) {
			switch(key) {
				case ContainerOptionKeys.INTERACTIVE: return new ContainerOption.from_value("interactive");
				case ContainerOptionKeys.TTY: return new ContainerOption.from_value("tty");
				case ContainerOptionKeys.PRIVILEGED: return new ContainerOption.from_value("privileged");
				case ContainerOptionKeys.NO_PERSISTENCE: return new ContainerOption.from_value("rm");
				case ContainerOptionKeys.RUNTIME: return new ContainerOption.with_name("runtime","crun");
				case ContainerOptionKeys.ENV_DISPLAY: return new ContainerOption.with_name("env","'DISPLAY'");
				case ContainerOptionKeys.ENV_SHELL: return new ContainerOption.with_name("env","'SHELL=/bin/bash'");
				case ContainerOptionKeys.NETWORK: return new ContainerOption.with_name("network","host");
				case ContainerOptionKeys.SECURITY_LABEL: return new ContainerOption.with_name("security-opt label","disable");
				case ContainerOptionKeys.USER_NAMESPACE: return new ContainerOption.with_name("userns","keep-id:uid=%s,gid=%s".printf(Utils.get_user_id(),Utils.get_group_id()));
				case ContainerOptionKeys.GROUP_ADD: return new ContainerOption.with_name("group-add","keep-groups");
				case ContainerOptionKeys.PID: return new ContainerOption.with_name("pid","host");
				case ContainerOptionKeys.USER: return new ContainerOption.with_name("user",Utils.get_username());
				case ContainerOptionKeys.ULIMIT: return new ContainerOption.with_name("ulimit","host");
				case ContainerOptionKeys.ANNOTATION: return new ContainerOption("--annotation run.oci.keep_original_groups=1");
				case ContainerOptionKeys.MOUNT_PTS: return new ContainerOption("--mount type=devpts,destination=/dev/pts");
				case ContainerOptionKeys.DETACHED: return new ContainerOption.from_value("detach");
				default:
					Logger.logp("ContainerOption","get_predefined",Level.SEVERE,"Unmanaged option key: %s".printf(key.value()));
					return null;
			}
		}
	}

	public enum ContainerStatus {
		RUNNING, CREATED, EXITED, PAUSED, UNKNOWN;

		public string to_icon() {
			switch(this) {
				case RUNNING: return "media-playback-start";
				case CREATED: return "process-stop";
				case EXITED: return "media-playback-stop";
				case PAUSED: return "media-playback-pause";
				case UNKNOWN: return "dialog-question";
				default: return "dialog-warning";
			}
		}

		public static ContainerStatus[] values() { return { RUNNING, CREATED, EXITED, PAUSED, UNKNOWN }; }

		public string value() { return this.to_string().down().replace("container_manager_container_status_",""); }
	}

	public class Container {

		public string id="-1";
		public ContainerManager.Image image = null;
		public string start_cmd = "";
		public List<ContainerManager.MountPoint> mounts = new List<ContainerManager.MountPoint>();
		public HashTable<string,ContainerManager.ContainerOption> options = new HashTable<string,ContainerOption>(str_hash,str_equal);

		public Container() { this.set_defaults(); }
		public Container.empty() {}
		public Container.with_id(string id) { this.id = id; }

		/* default options */
		public void add_predefined(string opt) {
			Logger.entering("Container","add_predefined");
			Logger.log(Level.FINE,"Search container option {0}", new string[] {opt});
			ContainerOptionKeys? key = ContainerOptionKeys.get(opt);
			if (key != null) {
				Logger.finest("Add default option");
				this.options.insert(opt,ContainerOption.get_predefined(key));
			}
			Logger.exiting("Container","add_predefined");
		}

		private void set_defaults() {
			Logger.entering("Container","set_default");
			Logger.finest("Add default options");
			this.options.insert(ContainerOptionKeys.INTERACTIVE.value(),ContainerOption.get_predefined(ContainerOptionKeys.INTERACTIVE));
			this.options.insert(ContainerOptionKeys.TTY.value(),ContainerOption.get_predefined(ContainerOptionKeys.TTY));
			this.options.insert(ContainerOptionKeys.PRIVILEGED.value(),ContainerOption.get_predefined(ContainerOptionKeys.PRIVILEGED));
			this.options.insert(ContainerOptionKeys.NO_PERSISTENCE.value(),ContainerOption.get_predefined(ContainerOptionKeys.NO_PERSISTENCE));
			this.options.insert(ContainerOptionKeys.RUNTIME.value(),ContainerOption.get_predefined(ContainerOptionKeys.RUNTIME));
			this.options.insert(ContainerOptionKeys.ENV_DISPLAY.value(),ContainerOption.get_predefined(ContainerOptionKeys.ENV_DISPLAY));
			this.options.insert(ContainerOptionKeys.ENV_SHELL.value(),ContainerOption.get_predefined(ContainerOptionKeys.ENV_SHELL));
			this.options.insert(ContainerOptionKeys.NETWORK.value(),ContainerOption.get_predefined(ContainerOptionKeys.NETWORK));
			this.options.insert(ContainerOptionKeys.SECURITY_LABEL.value(),ContainerOption.get_predefined(ContainerOptionKeys.SECURITY_LABEL));
			this.options.insert(ContainerOptionKeys.USER_NAMESPACE.value(),ContainerOption.get_predefined(ContainerOptionKeys.USER_NAMESPACE));
			this.options.insert(ContainerOptionKeys.GROUP_ADD.value(),ContainerOption.get_predefined(ContainerOptionKeys.GROUP_ADD));
			this.options.insert(ContainerOptionKeys.PID.value(),ContainerOption.get_predefined(ContainerOptionKeys.PID));
			this.options.insert(ContainerOptionKeys.USER.value(),ContainerOption.get_predefined(ContainerOptionKeys.USER));
			this.options.insert(ContainerOptionKeys.ULIMIT.value(),ContainerOption.get_predefined(ContainerOptionKeys.ULIMIT));
			this.options.insert(ContainerOptionKeys.ANNOTATION.value(),ContainerOption.get_predefined(ContainerOptionKeys.ANNOTATION));
			this.options.insert(ContainerOptionKeys.MOUNT_PTS.value(),ContainerOption.get_predefined(ContainerOptionKeys.MOUNT_PTS));
			Logger.finest("Add default mounts");
			this.add_mount("/dev:/dev:rslave");
			this.add_mount("/sys:/sys:rslave");
			this.add_mount("/tmp:/tmp:rslave");
			this.add_mount("/run/user/%s:/run/user/1000:rslave".printf(Utils.get_user_id()));
			Logger.exiting("Container","set_default");
		}

		/* custom options */
		public void add_custom() {
			ContainerOption co = new ContainerOption.empty();
			string key = (new DateTime.now_utc().to_unix()).to_string();
			this.options.insert(key,co);
		}

		public void update_custom(string key, string value) {
			ContainerOption co = new ContainerOption(value);
			this.options.insert(key,co);
		}

		public void remove_custom(string key) { this.options.remove(key); }

		/* getter */
		public string get_button_icon() { return PodmanManager.get_container_status(this.get_name()).to_icon(); }

		public string get_image_name() {
			if (this.image == null && this.options.contains(ContainerOptionKeys.NAME.value())) {
				Logger.log(Level.FINE, "Search for image with name {0}",new string[] {this.get_name()});
				this.set_image(this.get_name(),null);
			}
			if (!this.image.exists()) return "";
			return this.image.name;
		}

		public string get_name() { 
			return (this.options.contains(ContainerOptionKeys.NAME.value()))?
				this.options.lookup(ContainerOptionKeys.NAME.value()).get_value():this.id;
		}

		public string get_start_command() { return this.start_cmd; }

		public string get_username() {
			return (this.options.contains(ContainerOptionKeys.USER.value())?
				this.options.lookup(ContainerOptionKeys.USER.value()).get_value():
				Configuration.default_user);
		}
		
		/* setter */
		public void set_name (string name) { this.options.insert(ContainerOptionKeys.NAME.value(),new ContainerOption.with_name("name",name)); }
		public void set_username(string username) { this.options.insert(ContainerOptionKeys.USER.value(),new ContainerOption.with_name("user",username)); }
		public void set_start_command(string cmd) { this.start_cmd = cmd; }

		public void set_image(string name, string? id) {
			this.image = (id != null)?
				new ContainerManager.Image.with_id(name,id):
				new ContainerManager.Image(name);
		}

		/* quick preferences */
		public void enable_persistence() { this.options.remove(ContainerOptionKeys.NO_PERSISTENCE.value()); }
		public void enable_background() { this.options.insert(ContainerOptionKeys.DETACHED.value(),ContainerOption.get_predefined(ContainerOptionKeys.DETACHED)); }

		/* mounts */
		public void add_mount(string rule) {
			Logger.entering("Container","add_mount");
			Logger.log(Level.FINEST,"Mount rule: {0}", new string[]{rule});
			MountPoint mount;
			string[] splitted=rule.split(":");
			if (splitted.length == 3) {
				Logger.log(Level.FINEST,"Mount point with mode {2} for {0} ({1})", splitted);
				mount = new MountPoint.with_mode(splitted[0],splitted[1],splitted[2]);
			} else if (splitted.length == 2) {
				Logger.log(Level.FINEST,"Mount point with mount point for {0} ({1})", splitted);
				mount = new MountPoint.with_mount(splitted[0],splitted[1]);
			} else {
				Logger.log(Level.FINEST,"Mount point {0}", new string[]{rule});
				mount = new MountPoint(rule);
			}
			this.mounts.append(mount);
			Logger.exiting("Container","add_mount");
		}

		public bool remove_mount(string rule) {
			Logger.entering("Container","remove_mount");
			Logger.log(Level.FINEST,"Mount rule: {0}", new string[]{rule});
			foreach (MountPoint mount in this.mounts) {
				if (mount.rule() == rule) {
					Logger.log(Level.FINEST,"Mount rule {0} found, remove it", new string[] {rule});
					this.mounts.remove(mount);
					Logger.exiting("Container","remove_mount");
					return true;
				}
			}
			Logger.log(Level.WARNING,"Mount rule {0} not found", new string[] {rule});
			Logger.exiting("Container","remove_mount");
			return false;
		}

		/* commands */
		public string cmd() throws ImageError {
			Logger.entering("Container","cmd");
			if (this.image == null && this.options.contains(ContainerOptionKeys.NAME.value())) {
				Logger.log(Level.FINE, "Search for image with name {0}",new string[] {this.get_name()});
				this.set_image(this.get_name(),null);
			}
			if (!this.image.exists()) throw new ImageError.message("Invalid image");
			try {
				switch (PodmanManager.get_container_status(this.get_name())) {
					case RUNNING:
						return this.connect_command();
					case CREATED:
					case EXITED:
						return "%s && %s".printf(this.start_command(), this.connect_command());
					case PAUSED:
						return (PodmanManager.resume_container(this.get_name()))?
							this.connect_command():this.create_command();
					case UNKNOWN:
					default:
						return this.create_command();
				}
			} finally {
				Logger.exiting("Container","cmd");
			}
		}
		
		public string create_command() {
			Logger.entering("Container","create_command");
			string options_str = "";
			foreach (string key in this.options.get_keys()) {
				Logger.log(Level.FINER, "Add option {0} = {1}", new string[]{key, this.options.lookup(key).cmd()});
				options_str += " " + this.options.lookup(key).cmd();
			}
			Logger.log(Level.FINEST,"Number of mount points: {0}", new string[] {this.mounts.length().to_string()});
			foreach (MountPoint mount in this.mounts) {
				Logger.log(Level.FINER, "Add mounts {0}", new string[]{mount.rule()});
				options_str += " " + mount.cmd();
			}
			options_str += " " + this.image.cmd() + " " + this.start_cmd;
			Logger.log(Level.FINEST, "Final options: {0}", new string[] {options_str});
			Logger.exiting("Container","create_command");
			return "podman run " + options_str;
		}

		public string connect_command() {
			Logger.entering("Container","connect_command");
			string options_str = "";
			options_str += " " + (new ContainerOption.from_value("interactive")).cmd();
			options_str += " " + (new ContainerOption.from_value("tty")).cmd();
			options_str += " " + this.get_name();
			options_str += " " + Configuration.default_command;
			Logger.log(Level.FINEST, "Final options: {0}", new string[] {options_str});
			Logger.exiting("Container","connect_command");
			return "podman exec " + options_str;
		}

		public string start_command() {
			Logger.entering("Container","start_command");
			string options_str = "";
			options_str += " " + this.get_name();
			Logger.log(Level.FINEST, "Final options: {0}", new string[] {options_str});
			Logger.exiting("Container","start_command");
			return "podman start " + options_str;
		}

		public string stop_command() {
			Logger.entering("Container","stop_command");
			string options_str = "";
			options_str += " " + this.get_name();
			Logger.log(Level.FINEST, "Final options: {0}", new string[] {options_str});
			Logger.exiting("Container","stop_command");
			return "podman stop " + options_str;
		}

		/* status */
		public bool exists() {
			switch (PodmanManager.get_container_status(this.get_name())) {
				case EXITED:
				case RUNNING:
				case PAUSED:
					return true;
				default:
					return false;
			}
		}

		public bool is_resumable() {
			return PodmanManager.get_container_status(this.get_name()) == ContainerStatus.PAUSED;
		}
		
		public bool is_startable() {
			switch (PodmanManager.get_container_status(this.get_name())) {
				case EXITED:
				case UNKNOWN:
					return true;
				default:
					return false;
			}
		}

		public bool is_stoppable() {
			return PodmanManager.get_container_status(this.get_name()) == ContainerStatus.RUNNING;
		}

		/* json and file */
		public void load() {
			Logger.entering("Container","load");
			Logger.log(Level.FINE,"Load data for container id {0}", new string[] {this.id});
			Container c = Utils.parse_container_file(this.id);
			Logger.finest("Set image");
			this.image = c.image;
			Logger.finest("Set mounts");
			this.mounts = new List<ContainerManager.MountPoint>();
			foreach (MountPoint m in c.mounts) {
				this.mounts.append(m);
				Logger.log(Level.FINEST,"Copied mount {0}",new string[] {m.rule()});
			}
			Logger.finest("Copied mounts size: %s".printf(this.mounts.length().to_string()));
			Logger.finest("Set options");
			this.options = new HashTable<string,ContainerOption>(str_hash,str_equal);
			foreach (string key in c.options.get_keys()){
				this.options.insert(key,c.options.lookup(key));
			}
			Logger.exiting("Container","load");
		}

		public Json.Object to_json() throws ImageError {
			Logger.entering("Container","to_json");
			try {
				Json.Object root = new Json.Object();
				if (this.image == null && this.options.contains(ContainerOptionKeys.NAME.value())) {
					Logger.fine("Search for image with name like container name");
					this.set_image(this.options.lookup(ContainerOptionKeys.NAME.value()).get_value(),null);
				} else {
					Logger.log(Level.FINE,"Use image {0}", new string[] {this.image.get_identifier()});
				}
				if (!this.image.exists()) throw new ImageError.message("Invalid image");
				Json.Object j_opts = new Json.Object(); 
				foreach (string key in this.options.get_keys()){
					ContainerOption op = this.options.lookup(key);
					j_opts.set_object_member(key,op.to_json());
				}
				root.set_object_member("options",j_opts);
				Json.Array j_mounts = new Json.Array(); 
				foreach (ContainerManager.MountPoint mount in this.mounts) {
					j_mounts.add_string_element(mount.rule());
				}
				root.set_array_member("mounts",j_mounts);
				if (this.start_cmd.length > 0) root.set_string_member("cmd",this.start_cmd);
				if (this.image != null) root.set_string_member("image",this.image.get_identifier());
				return root;
			} catch (Error e) {
				Logger.stack_trace(e);
				throw new ImageError.message(e.message);
			} finally {
				Logger.exiting("Container","to_json");
			}
		}
	}
}
