

#include <neorv32.h>

/** UART BAUD rate */
#define BAUD_RATE 19200

void uart_print_x8(uint8_t val) {
  char buf[3];
  uint8_t i = 0;
  if (val == 0) {
    neorv32_uart0_putc('0');
    neorv32_uart0_putc('0');
    return;
  }
  if (val <= 0xf) {
    neorv32_uart0_putc('0');
  }
  while (val > 0) {
    buf[i++] = val % 16;
    val /= 16;
  }
  while (i > 0) {
    neorv32_uart0_putc("0123456789abcdef"[buf[--i]]);
  }
}
int main() {

  // capture all exceptions and give debug info via UART
  // this is not required, but keeps us safe
  neorv32_rte_setup();

  // setup UART at default baud rate, no interrupts
  neorv32_uart0_setup(BAUD_RATE, 0);

  // print project logo via UART
  neorv32_aux_print_logo();

  // say hello
  neorv32_uart0_puts("Hello world! :)\n");

  uint8_t *ptr = (uint8_t *)0x90000000;
  uint8_t *ptr_end = (uint8_t *)0x90000000 + (1024 * 5);
  while (ptr < ptr_end) {
    neorv32_uart0_printf("[%x]: ", ptr);
    for (int j = 0; j < 32; j++) {
      uart_print_x8(*ptr++);
      neorv32_uart0_puts(" ");
    }
    neorv32_uart0_puts("\n");
  }

  neorv32_uart0_puts("Erasing flash... \n");
  ptr = (uint8_t *)0x90000000;
  for (int i = 0; i < 38; i++) {
    neorv32_uart0_printf("[%x] \n", ptr);
    *ptr = 0;
    ptr += 2048;
  }

  neorv32_uart0_puts("Dumping again :(\n");
  ptr = (uint8_t *)0x90000000;
  ptr_end = (uint8_t *)0x90000000 + (1024 * 5);
  while (ptr < ptr_end) {
    neorv32_uart0_printf("[%x]: ", ptr);
    for (int j = 0; j < 32; j++) {
      neorv32_uart0_puts("0x");
      uart_print_x8(*ptr++);
      neorv32_uart0_puts(" ");
    }
    neorv32_uart0_puts("\n");
  }
  neorv32_uart0_puts("Bye! :(\n");

  return 0;
}
