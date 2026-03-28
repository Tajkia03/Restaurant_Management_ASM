.model small
    .stack 100h

    .data
    welcome_msg      db 13,10,'Welcome to Restaurant Management System$'
    login_msg        db 13,10,'Login as: 1. Admin  2. Staff$'
    invalid          db 13,10,'Invalid option. Restarting...$'

    password_msg     db 13,10,'Enter admin password: $'
    wrong_pass       db 13,10,'Incorrect password! Returning to login...$'
    correct_password db '1234$'
    input_pass       db 6 dup(0)       ; 4 chars + '$' + 1 safety byte

    admin_menu       db 13,10,'--- Admin Menu ---',13,10,'1. Set Menu',13,10,'2. Edit Menu',13,10,'3. View Menu',13,10,'4. Logout$'
    choose_option    db 13,10,'Choose an option (1-4): $'
    new_item_prompt  db 13,10,'Enter name for item: $'
    new_name_prompt  db 13,10,'Enter new name: $'
    edit_prompt      db 13,10,'Edit which item (1-3): $'
    inv_msg          db 13,10,'--- Current Menu ---$'
    newline          db 13,10,'$'

    ; Each item: 2-byte prefix (e.g. "1.") + space + 15 chars for name + '$'
    item1            db 13,10,'1. ','               ','$'   ; 15 spaces as placeholder
    item2            db 13,10,'2. ','               ','$'
    item3            db 13,10,'3. ','               ','$'

    menu_msg         db 13,10,'Choose Item (1-3, 0 to finish): $'
    qty_msg          db 13,10,'Enter Quantity: $'

    ; Prices in BDT
    prices           dw 120, 90, 100

    total            dw 0
    discount         dw 0
    final_amt        dw 0

    ; FIX: coupon_applied flag — 0 = no discount, 1 = discount applied
    coupon_applied   db 0

    msg1             db 13,10,'Total before discount: BDT.$'
    msg2             db 13,10,'Discount (10%%): BDT.$'      ; %% = literal % in DOS strings
    msg3             db 13,10,'Final amount: BDT.$'

    coupon_msg       db 13,10,'Enter coupon code (press Enter to skip): $'
    coupon_code      db 'SAVE10$'
    coupon_input     db 10 dup(0)
    discount_success db 13,10,'Coupon accepted! 10% discount applied.$'
    discount_fail    db 13,10,'Invalid or no coupon. No discount applied.$'

    ; FIX: day_flag — now toggled by admin; starts as weekday
    day_flag         db 0              ; 0 = Weekday, 1 = Weekend
    weekday_msg      db 13,10,'Today is a weekday. No special offer.$'
    special_msg      db 13,10,'Weekend Special: Free Brownie with any order!$'

    day_menu         db 13,10,'Set day: 1. Weekday  2. Weekend$'
    day_option       db 13,10,'Choose (1-2): $'

    invalid_item_msg db 13,10,'Invalid item. Choose 1-3 or 0.$'
    invalid_qty_msg  db 13,10,'Invalid quantity. Try again.$'

    .code
    main:
        mov ax, @data
        mov ds, ax

    ; ============================================================
    ;  LOGIN SCREEN
    ; ============================================================
    start_login:
        mov ah, 09h
        lea dx, welcome_msg
        int 21h

    login:
        mov ah, 09h
        lea dx, login_msg
        int 21h

        mov ah, 01h
        int 21h
        cmp al, '1'
        je admin_login
        cmp al, '2'
        je staff_order
        mov ah, 09h
        lea dx, invalid
        int 21h
        jmp login

    ; ============================================================
    ;  ADMIN LOGIN
    ; ============================================================
    admin_login:
        mov ah, 09h
        lea dx, password_msg
        int 21h

        lea di, input_pass
        mov cx, 4
    get_pass:
        mov ah, 08h            ; no-echo input
        int 21h
        mov [di], al
        inc di
        loop get_pass
        mov byte ptr [di], '$'

        lea si, input_pass
        lea di, correct_password
        call compare_strings
        cmp ax, 0
        je admin_menu_loop

        mov ah, 09h
        lea dx, wrong_pass
        int 21h
        jmp login

    ; ============================================================
    ;  ADMIN MENU
    ; ============================================================
    admin_menu_loop:
        mov ah, 09h
        lea dx, admin_menu
        int 21h
        mov ah, 09h
        lea dx, choose_option
        int 21h

        mov ah, 01h
        int 21h
        cmp al, '1'
        je set_menu
        cmp al, '2'
        je edit_menu
        cmp al, '3'
        je view_menu
        cmp al, '4'
        je return_to_login
        jmp admin_menu_loop

    ; ============================================================
    ;  SET MENU  (FIX: proper loop using counter, no CX conflict)
    ; ============================================================
    set_menu:
        ; --- Item 1 ---
        mov ah, 09h
        lea dx, new_item_prompt
        int 21h
        lea di, item1 + 5      ; skip 13,10,'1. ' (5 bytes)
        call read_item_name

        ; --- Item 2 ---
        mov ah, 09h
        lea dx, new_item_prompt
        int 21h
        lea di, item2 + 5
        call read_item_name

        ; --- Item 3 ---
        mov ah, 09h
        lea dx, new_item_prompt
        int 21h
        lea di, item3 + 5
        call read_item_name

        jmp admin_menu_loop

    ; ============================================================
    ;  EDIT MENU
    ; ============================================================
    edit_menu:
        mov ah, 09h
        lea dx, edit_prompt
        int 21h

        mov ah, 01h
        int 21h
        cmp al, '1'
        je edit1
        cmp al, '2'
        je edit2
        cmp al, '3'
        je edit3
        jmp admin_menu_loop

    edit1:
        lea di, item1 + 5
        jmp edit_input
    edit2:
        lea di, item2 + 5
        jmp edit_input
    edit3:
        lea di, item3 + 5

    edit_input:
        mov ah, 09h
        lea dx, new_name_prompt
        int 21h
        call read_item_name
        jmp admin_menu_loop

    ; ============================================================
    ;  VIEW MENU
    ; ============================================================
    view_menu:
        mov ah, 09h
        lea dx, inv_msg
        int 21h
        lea dx, item1
        int 21h
        lea dx, item2
        int 21h
        lea dx, item3
        int 21h
        jmp admin_menu_loop

    ; ============================================================
    ;  RETURN TO LOGIN
    ; ============================================================
    return_to_login:
        jmp login

    ; ============================================================
    ;  STAFF ORDER
    ; ============================================================
    staff_order:
        mov total, 0
        mov coupon_applied, 0   ; FIX: reset coupon flag each session

    order_loop:
        ; Show current menu
        mov ah, 09h
        lea dx, menu_msg
        int 21h

        call get_number
        cmp ax, 0
        je show_coupon          ; 0 = done ordering

        ; FIX: bounds check — valid items are 1, 2, 3
        cmp ax, 1
        jl invalid_choice
        cmp ax, 3
        jg invalid_choice

        dec ax                  ; make 0-based index
        mov si, ax
        shl si, 1               ; si = index * 2 for word array

        mov ah, 09h
        lea dx, qty_msg
        int 21h
        call get_number

        cmp ax, 0               ; FIX: reject zero quantity
        je invalid_qty

        mov cx, ax              ; quantity
        mov ax, prices[si]      ; price for chosen item
        mul cx                  ; ax = price * quantity (result in DX:AX)
        add total, ax
        jmp order_loop

    invalid_choice:
        mov ah, 09h
        lea dx, invalid_item_msg
        int 21h
        jmp order_loop

    invalid_qty:
        mov ah, 09h
        lea dx, invalid_qty_msg
        int 21h
        jmp order_loop

    ; ============================================================
    ;  COUPON CHECK
    ; ============================================================
    show_coupon:
        mov ah, 09h
        lea dx, coupon_msg
        int 21h

        ; Read coupon input (up to 6 chars or Enter)
        lea di, coupon_input
        mov cx, 6
    read_coupon:
        mov ah, 01h
        int 21h
        cmp al, 13              ; Enter pressed = done
        je coupon_done
        mov [di], al
        inc di
        loop read_coupon
    coupon_done:
        mov byte ptr [di], '$'

        lea si, coupon_input
        lea di, coupon_code
        call compare_strings
        cmp ax, 0
        je coupon_match

        ; No match
        mov ah, 09h
        lea dx, discount_fail
        int 21h
        mov coupon_applied, 0
        jmp show_bill

    coupon_match:
        mov ah, 09h
        lea dx, discount_success
        int 21h
        mov coupon_applied, 1   ; FIX: set flag only on valid coupon

    ; ============================================================
    ;  BILLING
    ; ============================================================
    show_bill:
        ; Print total before discount
        mov ah, 09h
        lea dx, msg1
        int 21h
        mov ax, total
        call print_number
        mov ah, 09h
        lea dx, newline
        int 21h

        ; FIX: only apply discount if coupon was valid
        cmp coupon_applied, 1
        jne no_discount

        ; Calculate 10% discount
        mov ax, total
        mov bx, 10
        xor dx, dx
        div bx
        mov discount, ax

        mov ah, 09h
        lea dx, msg2
        int 21h
        mov ax, discount
        call print_number
        mov ah, 09h
        lea dx, newline
        int 21h

        mov ax, total
        sub ax, discount
        mov final_amt, ax
        jmp print_final

    no_discount:
        mov discount, 0
        mov ax, total
        mov final_amt, ax

    print_final:
        mov ah, 09h
        lea dx, msg3
        int 21h
        mov ax, final_amt
        call print_number
        mov ah, 09h
        lea dx, newline
        int 21h

        ; FIX: day_flag check — show weekend special or weekday message
        mov al, day_flag
        cmp al, 1
        je show_special
        mov ah, 09h
        lea dx, weekday_msg
        int 21h
        jmp done

    show_special:
        mov ah, 09h
        lea dx, special_msg
        int 21h

    done:
        jmp start_login

    ; ============================================================
    ;  SUBROUTINE: compare_strings
    ;  IN:  SI = string1, DI = string2 (both '$'-terminated)
    ;  OUT: AX = 0 if equal, 1 if not equal
    ;  FIX: saves and restores SI, DI
    ; ============================================================
    compare_strings proc near
        push si
        push di
        push bx
    cmp_loop:
        mov al, [si]
        mov bl, [di]
        cmp al, bl
        jne cmp_not_equal
        cmp al, '$'
        je cmp_equal
        inc si
        inc di
        jmp cmp_loop
    cmp_equal:
        pop bx
        pop di
        pop si
        mov ax, 0
        ret
    cmp_not_equal:
        pop bx
        pop di
        pop si
        mov ax, 1
        ret
    compare_strings endp

    ; ============================================================
    ;  SUBROUTINE: read_item_name
    ;  IN:  DI = pointer to 15-byte name field in itemX
    ;  Clears the field first, then reads up to 15 chars
    ; ============================================================
    read_item_name proc near
        push di
        push cx

        ; Clear 15 bytes with spaces
        mov cx, 15
    clear_field:
        mov byte ptr [di], ' '
        inc di
        loop clear_field
        sub di, 15              ; reset DI to start of field

        ; Read characters
        mov cx, 15
    read_char:
        mov ah, 01h
        int 21h
        cmp al, 13              ; Enter = done
        je read_done
        mov [di], al
        inc di
        loop read_char
    read_done:
        pop cx
        pop di
        ret
    read_item_name endp

    ; ============================================================
    ;  SUBROUTINE: get_number
    ;  OUT: AX = number entered by user
    ;  FIX: correct digit reconstruction (MSD first using place value)
    ; ============================================================
    get_number proc near
        push bx
        push cx
        push dx

        xor bx, bx              ; bx = accumulated result
    gn_loop:
        mov ah, 01h
        int 21h
        cmp al, 13              ; Enter
        je gn_done
        cmp al, '0'
        jl gn_loop              ; ignore non-digit
        cmp al, '9'
        jg gn_loop
        sub al, '0'
        xor ah, ah              ; ax = digit value
        push ax
        mov ax, bx
        mov cx, 10
        mul cx                  ; bx = bx * 10
        pop cx
        add ax, cx              ; ax = bx*10 + new digit
        mov bx, ax
        jmp gn_loop
    gn_done:
        mov ax, bx

        pop dx
        pop cx
        pop bx
        ret
    get_number endp

    ; ============================================================
    ;  SUBROUTINE: print_number
    ;  IN:  AX = number to print (unsigned)
    ; ============================================================
    print_number proc near
        push ax
        push bx
        push cx
        push dx

        mov bx, 10
        xor cx, cx
    pn_push:
        xor dx, dx
        div bx
        push dx
        inc cx
        test ax, ax
        jnz pn_push
    pn_print:
        pop dx
        add dl, '0'
        mov ah, 02h
        int 21h
        loop pn_print

        pop dx
        pop cx
        pop bx
        pop ax
        ret
    print_number endp

    end main