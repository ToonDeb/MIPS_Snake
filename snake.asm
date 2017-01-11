# Welcome to Snake
# to play: 
#	- under "Tools" open 
#		- "Bitmap Display"
#		- "Keyboard and Display MMIO Simulator"
#	- in "Bitmap Display"
#		- set "Unit Width in Pixels" to 32
#		- set "Unit Height in Pixels" to 32
#		- set "Display Width in Pixels" to 512
#		- set "Display Height in Pixels" to 512
#		- resize window so the complete black screen is visible
#		- set "Base adress for display" to 0x10000000 (global data)
#		- click on "Connect to MIPS"
#	- in "Keyboard and Display MMIO Simulator"
#		- click on "Connect to MIPS"
#	- click on "assemble"
# 	- click on "run"
#	- click in the "KEYBOARD" section of "Keyboard and Display MMIO Simulator"
#
#	keybindings are in .data under key_[direction], you can change them to any letter you want
#	go through wall = continuing on other side
#	
#	Change difficulty by changing the "delay" variable
#	"Delay" is the time between 2 movements, in milliseconds
#	(For a real challenge, set this to 0) 
#
#	You die when you touch yourself
#	your score is displayed in the "Run I/O" section of this window
#
# Created By Toon Deburchgrave 
# while "studying" for his examns
# 8/01/2017 - 9/01/2017
# Student Bachelor Engineering Science: Computerscience at KU Leuven
.data
	key_up:			.ascii	"z"
	key_down:		.ascii	"s"
	key_left:		.ascii	"q"
	key_right:		.ascii	"d"
	delay:			.word	250		# delay in milliseconds
	
	bitmap_location:	.word	0x10000000
	screen_size:		.word	256
	screen_width:		.word	16
	background_colour:	.word	0x00000000
	snake_colour:		.word	0xFFFFFFFF
	food_colour:		.word	0x00FF0000
	snake_init_pos:		.word	120
	snake_init_dir:		.word	3		# 0 up 1 down 2 left 3 right
	kb_receiver_control:	.word	0xffff0000
	kb_receiver_data:	.word	0xffff0004
	
	fail_text:		.asciiz	"You lost \n"
	score_text:		.asciiz	"Your score is: "
.text
main:
	j	snake
snake:	
	jal	initialise_snake
	jal	snake_game
	jal	ending
	li	$v0	10
	syscall

ending:
	addi	$sp	$sp	-4
	sw	$ra	($sp)
	
	li	$t1	0		# score = 1
	lw	$t0	8($s0)		# next node
	ending_loop:
	addi	$t1	$t1	1	# score += 1
	beqz	$t0	ending_score	# next node = 0 => stop counting
	lw	$t0	8($t0)		# load next node
	j	ending_loop
	
	ending_score:
	la	$a0	fail_text
	li	$v0	4
	syscall
	
	la	$a0	score_text
	li	$v0	4
	syscall
	
	move	$a0	$t1
	li	$v0	1
	syscall
	
	lw	$ra	($sp)
	addi	$sp	$sp	4
	jr	$ra

# main game loop
# s0 = back node
# s1 = front node
# s2 = food location
# s3 = direction
# s4 = new location
# s5 = "spare" memory location
# t0 = screen width
# t1 = screen size
# t2 = new position
# t3 = last location of before last row
snake_game:
	addi	$sp	$sp	-4
	sw	$ra	($sp)
	
	snake_game_loop:
	
	la	$t0	screen_width	
	lw	$t0	($t0)
	la	$t1	screen_size
	lw	$t1	($t1)
	
	sub	$t3	$t1	$t0	# get last location of before last row
	
	lw	$t2	($s1)		# get last node location
	
	beq	$s3	0	snake_game_up
	beq	$s3	1	snake_game_down
	beq	$s3	2	snake_game_left
	j	snake_game_right
	
	snake_game_up:
	blt	$t2	$t0	s_l_to_bottom # lower than screen width => upper row
	sub	$t2	$t2	$t0
	j	snake_game_end_dir
	
	s_l_to_bottom:
	add	$t2	$t3	$t2
	j	snake_game_end_dir
	
	
	snake_game_down:
	bgt	$t2	$t3	s_l_to_top # higher than (screen_size - screen_width) => lower row
	add	$t2	$t2	$t0
	j	snake_game_end_dir
	
	s_l_to_top:
	sub	$t2	$t2	$t3
	j	snake_game_end_dir
	
	
	snake_game_left:
	div	$t2	$t0
	mfhi	$t4
	addi	$t2	$t2	-1	
	beq	$t4	0	s_g_to_right # jump if at left most column
	j	snake_game_end_dir
	
	s_g_to_right:
	add	$t2	$t2	$t0	# move one up, because if at left, minus one, moves one down and to other side
	j	snake_game_end_dir
	
	
	snake_game_right:
	div	$t2	$t0
	mfhi	$t4
	addi	$t2	$t2	1
	addi	$t5	$t0	-1
	beq	$t4	$t5	s_g_to_left # jump if at right most column
	j	snake_game_end_dir
	
	s_g_to_left:
	sub	$t2	$t2	$t0	# moves one down, because if at right, plus one, moves one up and to other side
	j	snake_game_end_dir
	

	snake_game_end_dir:
	move	$s4	$t2
	move	$a0	$t2
	jal	check_if_in_snake	# check if in snake
	beq	$v0	1	snake_game_terminate # if it is: jump to return
	
	beq	$s4	$s2	snake_game_food_eaten # if food at new location, jump to food_eaten
	j	snake_game_move
	
	
	snake_game_food_eaten:
	li	$a0	12
	jal	alloc			# add new memory for snake node
	move	$a0	$v0
	jal	add_node_to_front
	jal	new_food
	j	snake_game_end_loop
	
	
	snake_game_move:
	
	move	$a0	$s5		# get free space location in a0
	jal	add_node_to_front	# add a node to the front
	jal	remove_last_node	# remove the last node
	j	snake_game_end_loop
	
	
	snake_game_end_loop:
	
	jal	delay_game
	jal	check_keyboard
	j	snake_game_loop
	
	#ENDED HERE
	
	snake_game_terminate:		# return
	lw	$ra	($sp)
	addi	$sp	$sp	4
	jr	$ra
	
# clear screen
# set first node of snake
# set food to random location
initialise_snake:
	addi	$sp	$sp	-4
	sw	$ra	0($sp)
	
	jal	clear_screen
	jal	set_first_node
	jal	new_food
	
	la	$s3	snake_init_dir	# get initial direction from data
	lw	$s3	($s3)
	
	li	$a0	12		# allocate memory for the "free" location
	jal	alloc
	move	$s5	$v0
	
	lw	$ra	($sp)
	addi	$sp	$sp	4
	jr	$ra
	
# write zero to all screen locations
# t0 = screen location
# t1 = screen size
# t2 = background color
clear_screen:
	la	$t0	bitmap_location	# get screen memory location
	lw	$t0	($t0)
	la	$t1	screen_size	# get screen size
	lw	$t1	($t1)
	la	$t2	background_colour # get background colour
	lw	$t2	($t2)
	
	clear_screen_loop:
	sw	$t2	($t0)		# set colour of screen
	addi	$t0	$t0	4	# next screen memory location
	addi	$t1	$t1	-1	# counter minus 1
	beqz	$t1	clear_screen_return # if complete screen, return
	j	clear_screen_loop
	clear_screen_return:
	jr	$ra
	
# allocate the first 3 bits and set them
# set $s0 to first node
# set $s1 to first node (no last node yet)
set_first_node:
	addi	$sp	$sp	-4	# increase sp 
	sw	$ra	0($sp)		# save ra
	
	addi	$a0	$zero	12	# set argument for alloc to 12
	jal	alloc			# allocate 12 bytes on heap
	lw	$ra	0($sp)		# reload ra
	
	move	$s0	$v0		# set s0 to first node
	move	$s1	$v0		# set s1 to first node
	sw	$zero	4($s0)		# set next and previous of first node to zero
	sw	$zero	8($s0)
	
	la	$a0	snake_init_pos	# get initial position of snake
	lw	$a0	($a0)
	sw	$a0	0($s0)		# save location of first node
	jal	draw_snake_segment
	
	lw	$ra	0($sp)		# repair ra
	addi	$sp	$sp	4
	jr	$ra			# return

# set the colour of location to snake colour
# a0 = location
draw_snake_segment:
	addi	$sp	$sp	-4
	sw	$ra	($sp)
	
	la	$a1	snake_colour	# get snake colour
	lw	$a1	($a1)
	jal	set_colour		# set initial position to colour of snake
	
	lw	$ra	($sp)
	addi	$sp	$sp	4
	jr	$ra			# return
	
# set colour of location to background
# a0 = location
draw_background:
	addi	$sp	$sp	-4
	sw	$ra	($sp)
	
	la	$a1	background_colour # get snake colour
	lw	$a1	($a1)
	jal	set_colour		# set initial position to colour of snake
	
	lw	$ra	($sp)
	addi	$sp	$sp	4
	jr	$ra			# return

# a0 = position in screen
# a1 = colour
set_colour:
	la	$t0	bitmap_location # get location of bitmap
	lw	$t0	($t0)
	li	$t1	4
	mul	$a0	$a0	$t1
	add	$t0	$t0	$a0	# t0 = absolute pos in screen
	sw	$a1	($t0)		# set colour on screen
	jr	$ra			# return
	
# a0 = amount of bytes to be increased
# v0 = location of first free position
alloc:
	move	$v0	$gp		# save free position to v0
	add	$gp	$gp	$a0	# increase gp
	jr	$ra			# return
	
# generate new food pelet on random location
new_food:
	addi	$sp	$sp	-4
	sw	$ra	($sp)
	
	new_food_test_random:
	la	$a1	screen_size	# get screen size
	lw	$a1	($a1)
	li	$v0	42
	syscall				# a0 = random int, between 0 and screen_size
	move	$s2	$a0		# save random in s2
	
	jal	check_if_in_snake	# check if food position in snake
	li	$t0	1
	beq	$t0	$v0	new_food_test_random # if yes, get new random
	
	move	$a0	$s2		# a0 = food location	
	la	$a1	food_colour
	lw	$a1	($a1)		# a1 = food_colour
	jal	set_colour		# colour food cube
	
	lw	$ra	($sp)
	addi	$sp	$sp	4
	jr	$ra			# return
	
# a0 = position to check
# v0 = 1 if in snake, else v0 = 0
check_if_in_snake:
	
	lw	$t0	0($s0)		# get screen location of back node
	beq	$t0	$a0	c_i_i_s_yes	# check if same
	beq	$s0	$s1	c_i_i_s_no	# if s0 and s1 equal => only 1 node
	
	move	$t1	$s0		# set t1 to back node
	lw	$t1	8($t1)		# $t1 = next node 
	
	c_i_i_s_loop:
	lw	$t0	($t1)		# get location
	beq	$t0	$a0	c_i_i_s_yes	# check if same
	lw	$t1	8($t1)		# get next node
	beqz	$t1	c_i_i_s_no	# end reached, no conflict
	j	c_i_i_s_loop		# loop again
	
	c_i_i_s_yes:
	li	$v0	1		# set return to 1
	jr	$ra			# return
	
	c_i_i_s_no:
	li	$v0	0		# set return to 0
	jr	$ra			# return
	
# a0 = memory location of new segment
# s4 = new location
# s1 = pointer to front node
add_node_to_front:
	addi	$sp	$sp	-4
	sw	$ra	($sp)
	
	sw	$a0	8($s1)		# save pointer to new segment in previous front segment
	sw	$s1	4($a0)		# save pointer to old segment in front segment
	sw	$s4	0($a0)		# save location on screen of new segment
	sw	$zero	8($a0)		# set pointer to next segment to zero
	move	$s1	$a0
	
	move	$a0	$s4		# draw snake
	jal	draw_snake_segment
	
	lw	$ra	($sp)
	addi	$sp	$sp	4
	jr	$ra
	
# s0 pointer to back
# s1 pointer to front
# s5 pointer to now used "free" space
remove_last_node:
	addi	$sp	$sp	-4
	sw	$ra	($sp)
	
	lw	$t0	8($s0)		# t0 = pointer to new back
	beqz	$t0	r_l_n_just_one_node
	sw	$zero	4($t0)		# remove link to last node
	r_l_n_skip:
	lw	$a0	($s0)		# location of back node in a0
	
	move	$s5	$s0		# previous "back node" becomes free node
	move	$s0	$t0		# new "back node" becomes real back node
	
	jal	draw_background		# draw background on previous "back node"
	
	lw	$ra	($sp)
	addi	$sp	$sp	4
	jr	$ra			# return
	
	r_l_n_just_one_node:
	move	$t0	$s1
	j	r_l_n_skip
	
# delays the game by amount, specified in delay
delay_game:
	la	$a0	delay
	lw	$a0	($a0)
	li	$v0	32
	syscall
	jr	$ra

# check if keyboard is ready, set direction
# s3 is direction
check_keyboard:
	la	$t0	kb_receiver_control # get control
	lw	$t0	($t0)		# locatie van control
	lw	$t0	($t0)		# control info zelf
	
	andi	$t0	$t0	1	# get least significant bit
	li	$t1	1
	beq	$t0	$t1	c_k_detect
	jr	$ra
	
	c_k_detect:
	la	$t0	kb_receiver_data
	lw	$t0	($t0)		# locatie van data
	lw	$t0	($t0)		# data zelf
	
	la	$t1	key_up
	lb	$t1	($t1)
	beq	$t0	$t1	c_k_up
	
	la	$t1	key_down
	lb	$t1	($t1)
	beq	$t0	$t1	c_k_down
	
	la	$t1	key_left
	lb	$t1	($t1)
	beq	$t0	$t1	c_k_left
	
	la	$t1	key_right
	lb	$t1	($t1)
	beq	$t0	$t1	c_k_right
	
	jr	$ra
	c_k_up:
	li	$s3	0
	jr	$ra
	c_k_down:
	li	$s3	1
	jr	$ra
	c_k_left:
	li	$s3	2
	jr	$ra
	c_k_right:
	li	$s3	3
	jr	$ra	
		
#This is free and unencumbered software released into the public domain.
#
#Anyone is free to copy, modify, publish, use, compile, sell, or
#distribute this software, either in source code form or as a compiled
#binary, for any purpose, commercial or non-commercial, and by any
#means.

#In jurisdictions that recognize copyright laws, the author or authors
#of this software dedicate any and all copyright interest in the
#software to the public domain. We make this dedication for the benefit
#of the public at large and to the detriment of our heirs and
#successors. We intend this dedication to be an overt act of
#relinquishment in perpetuity of all present and future rights to this
#software under copyright law.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
#OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
#ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#OTHER DEALINGS IN THE SOFTWARE.
#
#For more information, please refer to <http://unlicense.org>

# exactly 500 lines? Nice!