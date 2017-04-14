
#include "processx-unix.h"

processx__child_list_t *child_list = NULL;

void processx__child_add(pid_t pid, SEXP status) {
  processx__child_list_t *child = malloc(sizeof(processx__child_list_t));
  child->pid = pid;
  child->status = status;
  child->next = child_list;
  child_list = child;
}

void processx__child_remove(pid_t pid) {
  processx__child_list_t *ptr = child_list, *prev = 0;
  while (ptr) {
    if (ptr->pid == pid) {
      if (prev) {
	prev->next = ptr->next;
      } else {
	child_list = ptr->next;
      }
      /* This is a memory leak, but freeing here results in
	 crashes, so we leave the leak open for now, and will
	 fix it later. */
      /* free(ptr); */
      return;
    }
    prev = ptr;
    ptr = ptr->next;
  }
}

processx__child_list_t *processx__child_find(pid_t pid) {
  processx__child_list_t *ptr = child_list;
  while (ptr) {
    if (ptr->pid == pid) return ptr;
    ptr = ptr->next;
  }
  return 0;
}
