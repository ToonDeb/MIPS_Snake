.data
	key_up:			.ascii	"z"
	key_down:		.ascii	"s"
	key_left:		.ascii	"q"
	key_right:		.ascii	"d"
	
	bitmap_location:	.word	0x10000000
	screen_size:		.word	256
	screen_width:		.word	16
	background_colour:	.word	0x00000000
	snake_colour:		.word	0xFFFFFFFF
	food_colour:		.word	0x00FF0000
	snake_init_pos:		.word	120
	snake_init_dir:		.word	2		# 0 up 1 down 2 left 3 right
	
	score_text:		.asciiz	"Your score is: "
.text

main:	
	j	snake
	

# NOT FINISHED
snake:	
	jal	initialise_snake
	jal	snake_game
	j 	end


# NOT FINISHED
# main game loop
# s0 = first node
# s1 = last node
# s2 = food location
# s3 = direction
# s4 = new location
#
# t0 = screen width
# t1 = screen size
# t2 = new position
# t3 = last location of before last row
snake_game:
	addi	$sp	$sp	-4
	sw	$ra	($sp)

	la	$t0	screen_width	
	lw	$t0	($t0)
	la	$t1	screen_size
	lw	$t1	($t1)
	
	sub	$t3	$t1	$t0	# get last location of before last row
	
	lw	$t2	($s2)		# get last node location
	
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
	
	s_g_to_left
	sub	$t2	$t2	$t0	# moves one down, because if at right, plus one, moves one up and to other side
	j	snake_game_end_dir
	
	
	snake_game_end_dir:
	move	$s4	$t2
	move	$t2	$a0
	jal	check_if_in_snake	# check if in snake
	beq	$v0	1	snake_game_terminate # if it is: jump to return
	
	#ENDED HERE
	
	snake_game_terminate:		# return
	lw	$ra	($sp)
	addi	$sp	$sp	4
	jr	$ra
	


#		INITIALIZATION

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
	
	sw	$ra	($sp)
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
	
	la	$a1	snake_colour	# get snake colour
	lw	$a1	($a1)
	jal	set_colour		# set initial position to colour of snake
	
	lw	$ra	0($sp)		# repair ra
	addi	$sp	$sp	4
	jr	$ra			# return

#		END INITIALIZATION	
	


#		TOOLS

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
	
# TODO: improve, to reuse locations	
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
	
	lw	$t0	0($s0)		# get screen location of first node
	beq	$t0	$a0	c_i_i_s_yes	# check if same
	beq	$s0	$s1	c_i_i_s_no	# if s0 and s1 equal => only 1 node
	
	move	$t1	$s0		# set t1 to first node
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
	
#		END TOOLS
end:	
	