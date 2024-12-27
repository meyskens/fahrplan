class SendResultPacket {
  final int command;
  final int seq;
  final int totalPackages;
  final int currentPackage;
  final int screenStatus;
  final int newCharPos0;
  final int newCharPos1;
  final int pageNumber;
  final int maxPages;
  final List<int> data;

  SendResultPacket({
    required this.command,
    this.seq = 0,
    this.totalPackages = 1,
    this.currentPackage = 0,
    this.screenStatus = 0x31, // Example value
    this.newCharPos0 = 0,
    this.newCharPos1 = 0,
    this.pageNumber = 1,
    this.maxPages = 1,
    required this.data,
  });

  List<int> build() {
    return [
      command,
      seq & 0xFF,
      totalPackages & 0xFF,
      currentPackage & 0xFF,
      screenStatus & 0xFF,
      newCharPos0 & 0xFF,
      newCharPos1 & 0xFF,
      pageNumber & 0xFF,
      maxPages & 0xFF,
      ...data,
    ];
  }
}
