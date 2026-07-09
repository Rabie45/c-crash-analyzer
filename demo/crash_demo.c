#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct node {
    int value;
    struct node *next;
} node_t;

node_t *find_node(node_t *head, int target) {
    node_t *cur = head;
    while (cur != NULL) {
        if (cur->value == target) {
            return cur;
        }
        cur = cur->next;
    }
    return NULL; /* not found */
}

int use_node(node_t *n) {
    /* BUG: caller never checks for NULL before this call */
    return n->value * 2;
}

int process_list(node_t *head, int target) {
    node_t *found = find_node(head, target);
    return use_node(found);
}

int main(void) {
    node_t a = { .value = 1, .next = NULL };
    node_t b = { .value = 2, .next = NULL };
    a.next = &b;

    printf("Looking for value 5 in a 2-node list...\n");
    int result = process_list(&a, 5); /* 5 isn't in the list -> find_node returns NULL */
    printf("Result: %d\n", result);

    return 0;
}
