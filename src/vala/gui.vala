using Gtk;

namespace ContainerManager {

	public class MainWindow: Window {

		private Container current = null;
		private Button current_btn = null;

		private Button purge_button = null;
		private Button edit_button = null;
		private Button start_button = null;
		private Button stop_button = null;
		private Button pause_button = null;
		private Button connect_button = null;
		private Button delete_button = null;
		private ListBox container_opt = null;
		private ListBox  container_list = null;

		private HashTable <string,string> image_list = null;
		private HashTable <string,string> configs_change = null;

		public MainWindow() {
			this.title = Configuration.program_title;
			this.window_position = WindowPosition.CENTER;
			set_default_size(400,300);
			Gtk.Box toolbar = new Gtk.Box(Orientation.HORIZONTAL, 0);
			Gtk.Button new_button = new Gtk.Button.from_icon_name("list-add");
			if (Configuration.show_label) new_button.set_label("New");
			new_button.clicked.connect(create_new);
			toolbar.pack_start(new_button,false,true,5);
			this.purge_button = new Gtk.Button.from_icon_name("list-remove");
			if (Configuration.show_label) this.purge_button.set_label("Remove");
			this.purge_button.clicked.connect(delete_conf);
			toolbar.pack_start(this.purge_button,false,true,5);
			Gtk.Button refresh_button = new Gtk.Button.from_icon_name("view-refresh");
			if (Configuration.show_label) refresh_button.set_label("Reload");
			refresh_button.clicked.connect(() => {this.refresh(true);});
			toolbar.pack_start(refresh_button,false,true,5);
			this.edit_button = new Gtk.Button.from_icon_name("accessories-text-editor");
			if (Configuration.show_label) this.edit_button.set_label("Edit");
			this.edit_button.clicked.connect(edit);
			toolbar.pack_start(this.edit_button,false,true,5);
			this.start_button = new Gtk.Button.from_icon_name("media-playback-start");
			if (Configuration.show_label) this.start_button.set_label("Start");
			this.start_button.clicked.connect(start);
			toolbar.pack_start(this.start_button,false,true,5);
			this.stop_button = new Gtk.Button.from_icon_name("media-playback-stop");
			if (Configuration.show_label) this.stop_button.set_label("Stop");
			this.stop_button.clicked.connect(stop);
			toolbar.pack_start(this.stop_button,false,true,5);
			this.pause_button = new Gtk.Button.from_icon_name("media-playback-pause");
			if (Configuration.show_label) this.pause_button.set_label("Pause");
			this.pause_button.clicked.connect(pauseresume);
			toolbar.pack_start(this.pause_button,false,true,5);
			this.delete_button = new Gtk.Button.from_icon_name("process-stop");
			if (Configuration.show_label) this.delete_button.set_label("Delete");
			this.delete_button.clicked.connect(delete_container);
			toolbar.pack_start(this.delete_button,false,true,5);
			this.connect_button = new Gtk.Button.from_icon_name("network-workgroup");
			if (Configuration.show_label) this.connect_button.set_label("Connect");
			this.connect_button.clicked.connect(connect_to_container);
			toolbar.pack_start(this.connect_button,false,true,5);
			Gtk.Button pref_btn = new Gtk.Button.from_icon_name("preferences-system");
			if (Configuration.show_label) pref_btn.set_label("Prefrences");
			pref_btn.clicked.connect(show_prefs);
			toolbar.pack_end(pref_btn,false,true,5);
			this.container_list = new Gtk.ListBox();
			this.container_opt = new Gtk.ListBox();
			ScrolledWindow scroll_central = new ScrolledWindow(null,null);
			scroll_central.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
			scroll_central.add(this.container_opt);
			ScrolledWindow scroll_list = new ScrolledWindow(null, null);
			scroll_list.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
			scroll_list.add(this.container_list);
			Box hbox = new Box(Orientation.HORIZONTAL, 5);
			hbox.pack_start(scroll_list,false,true,5);
			hbox.pack_start(scroll_central,true,true,5);
			Box vbox = new Box(Orientation.VERTICAL, 5);
			vbox.pack_start(toolbar,false,true,5);
			vbox.pack_start(hbox,true,true,5);
			add(vbox);
			this.image_list = PodmanManager.get_image_list();
			foreach (string key in Configuration.get_container_keys())
				this.add_container(key);
			this.reload_cmd_btn();
			this.timer();
		}

		/* internal utils */
		public void timer() {
			this.refresh(false);
			Timeout.add(Configuration.wait_timeout, () => {
				this.timer();
				return false;
			});
		}

		public void empty_center() {
			foreach (Gtk.Widget element in this.container_opt.get_children()) {
				this.container_opt.remove(element);
				element.destroy();
			}
		}

		public void set_widget_status(Widget widg, bool enabled = true) {
			widg.set_sensitive(enabled);
			widg.can_focus = (enabled);
		}

		public void reload_cmd_btn() {
			Logger.entering("MainWindow","reload_cmd_btn");
			this.set_widget_status(this.edit_button,   false);
			this.set_widget_status(this.purge_button,  false);
			this.set_widget_status(this.delete_button, false);
			this.set_widget_status(this.start_button,  false);
			this.set_widget_status(this.stop_button,   false);
			this.set_widget_status(this.pause_button,  false);
			this.set_widget_status(this.connect_button,false);
			if (this.current_btn != null) this.current_btn.set_image(new Gtk.Image.from_icon_name(this.current.get_button_icon(),Gtk.IconSize.BUTTON));
			if (this.current != null) {
				this.set_widget_status(this.edit_button,  true);
				this.set_widget_status(this.purge_button,  true);
				this.set_widget_status(this.delete_button, this.current.exists());
				this.set_widget_status(this.start_button,this.current.is_startable());
				this.set_widget_status(this.stop_button,this.current.is_stoppable());
				this.set_widget_status(this.connect_button,this.current.is_stoppable());
				this.set_widget_status(this.pause_button,this.current.is_resumable() || this.current.is_stoppable());
			}
			Logger.exiting("MainWindow","reload_cmd_btn");
		}
	
		public void add_container(string id) {
			Logger.entering("MainWindow","add_container");
			Container c = Configuration.get_container(id);
			if (c != null) {
				Logger.log(Level.FINE,"Parse: {0}", new string[] {c.get_name()});
				Gtk.Button button_c = new Gtk.Button.from_icon_name(c.get_button_icon());
				button_c.set_label(c.get_name());
				button_c.set_name(id);
				button_c.clicked.connect(container_select);
				this.container_list.insert(button_c,-1);
				this.show_all();
			} else {
				Logger.log(Level.SEVERE,"Container with id {0} not found",new string[] {id});
			}
		}

		/* toolbar button functions */
		public void create_new() {
			Logger.entering("MainWindow","create_new");
			this.current_btn = null;
			this.current = null;
			this.reload_cmd_btn();
			this.current = new Container();
			this.load_info(true);
			Logger.exiting("MainWindow","create_new");
		}

		public void edit() { this.load_info(true); }

		public void delete_conf() {
			if (this.current != null) {
				if (this.current.exists()) {
					if (!Utils.yesno("Podman delete","Are you sure you want to delete the container with name %s?".printf(this.current.get_name()),this))
						return;
					if (!PodmanManager.delete_container(this.current.get_name())) return;
				}
				if (Utils.yesno("Configuration delete","Delete configuration for container %s?".printf(this.current.get_name()),this)) {
					if(Utils.delete_container_file(this.current.id)) {
						this.container_list.remove(this.current_btn);
						this.current = null;
						this.current_btn = null;
						this.empty_center();
					}
				}
			}
		}

		public void refresh(bool reload_images=true) {
			Logger.entering("MainWindow","refresh");
			this.reload_cmd_btn();
			foreach (Gtk.Widget element in this.container_list.get_children()) {
				Gtk.ListBoxRow row = (Gtk.ListBoxRow) element;
				Gtk.Button btn = (Gtk.Button) row.get_children().first().data;
				Logger.log(Level.FINEST,"Reload container {0}", new string[] {btn.get_name()});
				Container c = Configuration.get_container(btn.get_name());
				btn.set_label(c.get_name());
				Logger.log(Level.FINEST,"Icon for container {0} = {1}", new string[] {btn.get_name(),c.get_button_icon()});
				btn.set_image(new Gtk.Image.from_icon_name(c.get_button_icon(), Gtk.IconSize.BUTTON));
			}
			if (reload_images) {
				this.image_list = PodmanManager.get_image_list();
				Logger.fine("Image list builded");
			}
			Logger.exiting("MainWindow","refresh");
		}

		/* toolbar existing container */
		public void start() {
			Logger.entering("MainWindow","start");
			if (this.current != null) {
				string exec_cmd;
				int runCommand;
				exec_cmd = this.current.cmd();
				runCommand = Utils.execute(Configuration.term_exec.printf(exec_cmd)+ " & ");
				Logger.log(Level.FINEST,"Command execution status: {0}", new string[] {"%d".printf(runCommand)});
				Logger.log(Level.FINE,"Wait for {0} ms", new string[] { "%d".printf(Configuration.wait_timeout)});
			}
			Logger.exiting("MainWindow","start");
		}

		public void stop() {
			Logger.entering("MainWindow","stop");
			if (this.current != null && this.current.is_stoppable()) {
				string exec_cmd = this.current.stop_command();
				Logger.log(Level.FINEST, "Command to execute:  {0}", new string[] { exec_cmd } );
				int runCommand = Posix.system(exec_cmd);
				Logger.log(Level.FINEST,"Command execution status: {0}", new string[] {"%d".printf(runCommand)});
				this.current_btn.set_image(new Gtk.Image.from_icon_name(this.current.get_button_icon(),Gtk.IconSize.BUTTON));
			}
			Logger.exiting("MainWindow","stop");
		}

		public void pauseresume() {
			if (this.current != null) {
				if (this.current.is_stoppable()) {
					if (!PodmanManager.pause_container(this.current.get_name())) {
						string text = "Unable to pause container %s".printf(this.current.id);
						Logger.logp("MainWindow","pauseresume",Level.SEVERE,text);
						Utils.error("Error pausing container",text,this);
					}
				} else if (this.current.is_resumable()) {
					if (!PodmanManager.resume_container(this.current.get_name())) {
						string text ="Unable to resume container %s".printf(this.current.id);
						Logger.logp("MainWindow","pauseresume",Level.SEVERE,text);
						Utils.error("Error pausing container",text,this);
					}
				} else {
					Logger.logp("MainWindow","pauseresume",Level.WARNING, "Container %s is not pausable or resumeable".printf(this.current.id));
					Utils.error("Error","Container is in an unexpected status",this);
				}
			}
		}

		public void delete_container() {
			if (this.current != null && Utils.yesno("Podman delete","Are you sure you want to delete the container with name %s?".printf(this.current.get_name()),this))
				PodmanManager.delete_container(this.current.get_name());
		}

		public void connect_to_container() {
			Logger.entering("MainWindow","connect_to_container");
			if (this.current != null) {
				string exec_cmd;
				int run;
				exec_cmd = this.current.connect_command();
				run = Utils.execute(Configuration.term_exec.printf(exec_cmd)+ " & ");
				Logger.log(Level.FINEST,"Command execution status: {0}", new string[] {"%d".printf(run)});
			}
			Logger.exiting("MainWindow","connect_to_container");
		}

		/* preferences */
		public void show_prefs() {
			this.current = null;
			this.current_btn = null;
			this.refresh(false);
			this.empty_center();
			Gtk.Box linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
			Gtk.CheckButton check = new Gtk.CheckButton.with_label("Show button labels");
			check.set_active(Configuration.show_label);
			check.toggled.connect((t_check) => { Configuration.show_label  = t_check.active; });
			linebox.pack_start(check,false,true,5);
			this.container_opt.insert(linebox,-1);
			linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
			Gtk.Label label = new Gtk.Label("Refresh timeout:");
			Gtk.Entry entry = new Gtk.Entry();
			entry.set_text("%d".printf(Configuration.wait_timeout));
			entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, "document-save");
			entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "edit-undo");
			entry.icon_press.connect((text,pos,event) => {
				if (pos == Gtk.EntryIconPosition.SECONDARY) { Configuration.wait_timeout = int.parse(text.get_text()); }
				else if (pos == Gtk.EntryIconPosition.SECONDARY) { text.set_text("%d".printf(Configuration.wait_timeout)); }
			});
			linebox.pack_start(label,false,true,5);
			linebox.pack_start(entry,true,true,5);
			this.container_opt.insert(linebox,-1);
			linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
			label = new Gtk.Label("Command to execute for launch: ");
			entry = new Gtk.Entry();
			entry.set_text(Configuration.term_exec);
			entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, "document-save");
			entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "edit-undo");
			entry.icon_press.connect((text,pos,event) => {
				if (pos == Gtk.EntryIconPosition.SECONDARY) { Configuration.term_exec = text.get_text(); }
				else if (pos == Gtk.EntryIconPosition.SECONDARY) { text.set_text(Configuration.term_exec); }
			});
			linebox.pack_start(label,false,true,5);
			linebox.pack_start(entry,true,true,5);
			this.container_opt.insert(linebox,-1);
			linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
			label = new Gtk.Label("Default container user:");
			entry = new Gtk.Entry();
			entry.set_text(Configuration.default_user);
			entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, "document-save");
			entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "edit-undo");
			entry.icon_press.connect((text,pos,event) => {
				if (pos == Gtk.EntryIconPosition.SECONDARY) {
					Configuration.default_user = text.get_text();
				} else if (pos == Gtk.EntryIconPosition.SECONDARY) {
					text.set_text(Configuration.default_user);
				}
			});
			linebox.pack_start(label,false,true,5);
			linebox.pack_start(entry,true,true,5);
			this.container_opt.insert(linebox,-1);
			linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
			label = new Gtk.Label("Default container command to start:");
			entry = new Gtk.Entry();
			entry.set_text(Configuration.default_command);
			entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, "document-save");
			entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "edit-undo");
			entry.icon_press.connect((text,pos,event) => {
				if (pos == Gtk.EntryIconPosition.SECONDARY) {
					Configuration.default_command = text.get_text();
				} else if (pos == Gtk.EntryIconPosition.SECONDARY) {
					text.set_text(Configuration.default_command);
				}
			});
			linebox.pack_start(label,false,true,5);
			linebox.pack_start(entry,true,true,5);
			this.container_opt.insert(linebox,-1);
			// button
			linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
			Gtk.Button save = new Gtk.Button.from_icon_name("document-save");
			if (Configuration.show_label) save.set_label("Save");
			save.clicked.connect((button) => { Configuration.save_to_file(); });
			linebox.pack_start(save,false,true,5);
			this.container_opt.insert(linebox,-1);
			this.container_opt.show_all();
		}

		/* container info */
		public void load_info(bool editable=false) {
			Logger.entering("MainWindow","load_info");
			this.empty_center();
			if (this.current != null) {
				Logger.log(Level.FINE, "Load info for container with id {0}", new string[] { this.current.id});
				Gtk.Box linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
				Gtk.Label label = new Gtk.Label("Name:");
				Gtk.Entry entry = new Gtk.Entry();
				entry.set_text(this.current.get_name());
				entry.editable=editable;
				entry.can_focus=editable;
				if (editable) {
					entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, "document-save");
					entry.icon_press.connect((text,pos,event) => {
						if (pos == Gtk.EntryIconPosition.SECONDARY) { this.current.set_name(text.get_text()); }
					});
				}
				linebox.pack_start(label,false,true,5);
				linebox.pack_start(entry,true,true,5);
				this.container_opt.insert(linebox,-1);
				// image
				linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
				label = new Gtk.Label("Image:");
				Gtk.ComboBoxText textbox = new Gtk.ComboBoxText();
				int i = 0;
				string a_img = this.current.get_image_name();
				Logger.log(Level.FINE,"Image associated: {0}",new string[] {a_img});
				string x_name = "%s:latest".printf(a_img);
				foreach (string name in this.image_list.get_keys()) {
					textbox.append_text(name);
					string im_id = this.image_list.lookup(name);
					if (name == a_img || name == x_name || a_img == im_id) textbox.active = i;
					i++;
				}
				textbox.changed.connect(() => {
					string img_name = textbox.get_active_text();
					string id = this.image_list.lookup(img_name);
					this.current.set_image(img_name,id);
				});
				textbox.set_sensitive(editable);
				textbox.can_focus = editable;
				linebox.pack_start(label,false,true,5);
				linebox.pack_start(textbox,true,true,5);
				this.container_opt.insert(linebox,-1);
				// user
				linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
				label = new Gtk.Label("User:");
				entry = new Gtk.Entry();
				entry.set_text(this.current.get_username());
				entry.editable=editable;
				entry.can_focus = editable;
				if (editable) {
					entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, "document-save");
					entry.icon_press.connect((text,pos,event) => {
						if (pos == Gtk.EntryIconPosition.SECONDARY) {
							this.current.set_username(text.get_text());
						}
					});
				}
				linebox.pack_start(label,false,true,5);
				linebox.pack_start(entry,true,true,5);
				this.container_opt.insert(linebox,-1);
				// start_cmd
				linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
				label = new Gtk.Label("Command:");
				entry = new Gtk.Entry();
				entry.set_text(this.current.get_start_command());
				entry.editable=editable;
				entry.can_focus = editable;
				if (editable) {
					entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, "document-save");
					entry.icon_press.connect((text,pos,event) => {
						if (pos == Gtk.EntryIconPosition.SECONDARY) {
							this.current.set_start_command(text.get_text());
						}
					});
				}
				linebox.pack_start(label,false,true,5);
				linebox.pack_start(entry,true,true,5);
				this.container_opt.insert(linebox,-1);
				// options
				linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
				label = new Gtk.Label("Options");
				label.can_focus = false;
				label.set_sensitive(false);
				linebox.pack_start(label,false,true,5);
				this.container_opt.insert(linebox,-1);
				Gtk.FlowBox multibox = new Gtk.FlowBox();
				foreach (ContainerOptionKeys key in ContainerOptionKeys.values()) {
					if (key == ContainerOptionKeys.NAME || key == ContainerOptionKeys.USER ) continue;
					string text = key.value();
					text = "%s%s".printf(text.substring(0,1).up(), text.substring(1).replace("_"," "));
					Gtk.CheckButton check = new Gtk.CheckButton.with_label(text);
					check.set_name(key.value());
					if (this.current.options.contains(key.value())) { check.set_active(true); }
					if (editable) {
						check.toggled.connect((t_check) => {
							Logger.logp("MainWindow","load_info",Level.FINEST,"Check click for %s".printf(check.get_name()));
							if (t_check.active) {
								this.current.add_predefined(t_check.get_name());
							} else {
								this.current.options.remove(t_check.get_name());
							}
						});
					}
					check.set_sensitive(editable);
					check.can_focus = editable;
					multibox.insert(check,-1);
				}
				this.container_opt.insert(multibox,-1);
				// raw options
				linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
				label = new Gtk.Label("Custom options");
				label.can_focus = false;
				label.set_sensitive(false);
				linebox.pack_start(label,false,true,5);
				if (editable) {
					Gtk.Button addc = new Gtk.Button.from_icon_name("list-add");
					addc.clicked.connect(() => {
						Logger.logp("MainWindow","load_info",Level.FINEST,"Add custom option");
						this.current.add_custom();
						Logger.logp("MainWindow","load_info",Level.FINEST,"Reload data");
						this.load_info(true);
					});
					linebox.pack_start(addc,false,true,5);
				}
				this.container_opt.insert(linebox,-1);
				foreach (string k in this.current.options.get_keys()) {
					if (ContainerOptionKeys.get(k) != null) continue;
					ContainerOption co = this.current.options.lookup(k);
					if (co.is_raw()) {
						linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
						entry = new Gtk.Entry();
						entry.set_text(co.get_value());
						entry.set_name(k);
						entry.editable=editable;
						entry.can_focus = editable;
						if (editable) {
							entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "document-save");
							entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, "list-remove");
							entry.icon_press.connect((text,pos,event) => {
								if (pos == Gtk.EntryIconPosition.PRIMARY) {
									this.current.update_custom(text.get_name(),text.get_text());
								} else if (pos == Gtk.EntryIconPosition.SECONDARY) {
									this.current.remove_custom(text.get_name());
								}
							});
						}
						linebox.pack_start(entry,true,true,5);
						this.container_opt.insert(linebox,-1);
					}
				}
				// mounts
				linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
				label = new Gtk.Label("Mounts");
				label.can_focus = false;
				label.set_sensitive(false);
				linebox.pack_start(label,false,true,5);
				if (editable) {
					Gtk.Button addm = new Gtk.Button.from_icon_name("list-add");
					addm.clicked.connect(() => {
						this.current.add_mount("undefined");
						this.load_info(true);
					});
					linebox.pack_start(addm,false,true,5);
				}
				this.container_opt.insert(linebox,-1);
				foreach (MountPoint mount in this.current.mounts) {
					linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
					entry = new Gtk.Entry();
					entry.set_text(mount.rule());
					entry.set_name(mount.rule());
					entry.editable=editable;
					entry.can_focus = editable;
					linebox.pack_start(entry,true,true,5);
					if (editable) {
						entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, "document-save");
						entry.icon_press.connect((text,pos,event) => {
							if (pos == Gtk.EntryIconPosition.SECONDARY) {
								this.current.remove_mount(text.get_name());
								this.current.add_mount(text.get_text());
							}
						});
						Gtk.Button btn_del = new Gtk.Button.from_icon_name("list-remove");
						btn_del.set_name(mount.rule());
						btn_del.clicked.connect(() => {
							if (this.current.remove_mount(btn_del.get_name())) this.load_info(true);
						});
							linebox.pack_start(btn_del,false,true,5);
						}
					this.container_opt.insert(linebox,-1);
				}      
				if (editable) {
					// buttons
					Gtk.Button undo = new Gtk.Button.from_icon_name("edit-undo");
					if (Configuration.show_label) undo.set_label("Cancel");
					undo.clicked.connect(() => {
						this.current.load();
						this.load_info();
					});
					Gtk.Button save = new Gtk.Button.from_icon_name("document-save");
					if (Configuration.show_label) save.set_label("Save");
					save.clicked.connect(() => {
						if (Utils.save_container_file(this.current)) {
							this.current.load();
							this.load_info();
						} else Utils.error("Unable to save config", "Unable to save configuration for container %s".printf(this.current.get_name()));
					});
					linebox = new Gtk.Box(Orientation.HORIZONTAL, 0);
					linebox.pack_start(undo,false,true,5);
					linebox.pack_start(save,false,true,5);
					this.container_opt.insert(linebox,-1);
				}
			}
			this.container_opt.show_all();
			Logger.exiting("MainWindow","load_info");
		}

		/* container list */
		public void container_select(Gtk.Button button) {
			Logger.entering("MainWindow","container_select");
			this.current_btn = button;
			string key = button.get_name();
			Logger.finest("Retrieve data for container with id " + key);
			this.current = Configuration.get_container(key);
			this.load_info();
			this.reload_cmd_btn();
		}
	}
}
