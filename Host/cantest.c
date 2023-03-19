#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>

#include <linux/can.h>
#include <linux/can/raw.h>

int main(int argc, char **argv)
{
  int                 s;
  int                 nbytes;
  struct sockaddr_can addr;
  struct ifreq        ifr;
  struct can_frame    frame;
  const char         *canIface = "slcan0";

  printf("CAN Sockets Receive Demo\r\n");

  if ((s = socket(PF_CAN, SOCK_RAW, CAN_RAW)) < 0)
  {
    perror("Socket");
    return 1;
  }

  if (argc >= 2)
  {
    canIface = argv[1];
  }

  strcpy(ifr.ifr_name, canIface);
  ioctl(s, SIOCGIFINDEX, &ifr);

  memset(&addr, 0, sizeof(addr));
  addr.can_family  = AF_CAN;
  addr.can_ifindex = ifr.ifr_ifindex;

  if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) < 0)
  {
    perror("[HOST] Bind");
    return 1;
  }

  unsigned cnt = 0;
  while (1)
  {
    char data[sizeof(frame.data) + 1] = {0};
    nbytes = read(s, &frame, sizeof(struct can_frame));

    if (nbytes < 0 || frame.can_dlc > sizeof(frame.data))
    {
      perror("[HOST] Read");
      return 1;
    }

    memcpy(data, frame.data, frame.can_dlc);
    printf("[HOST] Can received: %s\n", data);

    memset(frame.data, 0, sizeof(frame.data));
    snprintf((char *)frame.data, sizeof(frame.data), "%uYO", ++cnt);

    write(s, &frame, sizeof(frame));
    printf("[HOST] Can transmitted #%u\n", cnt);
  }

  if (close(s) < 0)
  {
    perror("Close");
    return 1;
  }

  return 0;
}
