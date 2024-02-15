namespace ContainerManager {

	public class MountPoint {
		private string host;
		private string container;
		private string mode = null;

		public MountPoint(string path) {
			this.host=path;
			this.container=this.host;
		}

		public MountPoint.with_mount(string host, string container) {
			this.host=host;
			this.container=container;
		}

		public MountPoint.with_mode(string host, string container, string mode) {
			this.host=host;
			this.container=container;
			this.mode = mode;
		}

		public string cmd() {
			Logger.entering("MountPoint","cmd");
			string last="";
			if (this.host == null || this.container == null) return "";
			if (this.mode != null) last = ":%s".printf(this.mode);
			Logger.log(Level.FINEST,"Rule: {0}",new string[] { this.rule() });
			Logger.exiting("MountPoint","cmd");
			return " --volume %s:%s%s".printf(this.host, this.container,last);
		}

		public string rule() { 
			string last="";
			if (this.mode != null) last = ":%s".printf(this.mode);
			return "%s:%s%s".printf(this.host, this.container,last);
		}
	}

	public class Image {
		public string id = null;
		public string name;

		public Image(string name) { this.name = name; }
		public Image.with_id(string name, string id) {
			this(name);
			this.id = id;
		}

		public bool exists() {
			if (this.id == null) {
				this.id = ContainerManager.PodmanManager.get_image_id(this.name);
				Logger.logp("Image","exists",Level.FINEST,"id: %s (%s)".printf(this.id, (this.id != null)?"true":"false"));
				return (this.id != null);
			} else {
				return ContainerManager.PodmanManager.get_image_name(this.id) != null;
			}
		}

		public string cmd() {
			if (this.id == null) this.id = ContainerManager.PodmanManager.get_image_id(this.name);
			return (this.id == null)?this.name:this.id;
		}

		public string get_identifier() { return (this.id != null)?this.id:this.name; }
	}
}
