# $arg0: main arena address
# $arg1: bin list number
define free_chunk_list
	# adress where bin starts
	set $start = (long *) ($arg0 + 56 + $arg1 * 8)

	# address malloc returned to programm
	set $free_chunk = (long *) ($start[1] + 8)
	set $chunk_count = 0
	set $chunk_max_size = 0
	set $total_size = 0
	
	while ($free_chunk != $start)
		set $chunk_size = ($free_chunk[-1] & ~7) 
		printf "Chunk adress: 0x%x  size:%i  fd:0x%x  bk:0x%x \n", $free_chunk, $chunk_size, $free_chunk[0], $free_chunk[1]

		if ($chunk_count == 0)
			set $chunk_max_size = $chunk_size 
			set $chunk_min_size = $chunk_size
		else
			if ($chunk_min_size > $chunk_size)
				set $chunk_min_size = $chunk_size
			end
			if ($chunk_max_size < $chunk_size)
				set $chunk_max_size = $chunk_size
			end
		end

		set $chunk_count = $chunk_count + 1
		set $total_size = $total_size + $chunk_size
		set $free_chunk = (long *) ($free_chunk[1] + 8)
	end

	if ($chunk_count == 0)
 		printf "Bin number %i: empty\n", $arg1 + 1
 	else
 		printf "Bin number %i: %i chunks (%i - %i bytes), total = %i bytes\n", $arg1 + 1, $chunk_count, $chunk_min_size,     $chunk_max_size, $total_size
 	end
end

# $arg0: main arena address
define print_stat
	set $alloc_reached =  (long *) ($arg0 + 1096)
	set $top_address = (long *) ($arg0 + 48)
	set $top_size_address = (long *) ($top_address[0] + 4)

	# Previous in use flag is always set for top chunk
	set $top_chunk_size = $top_size_address[0] - 1
	set $live_memory = $alloc_reached[0] - $free_in_arena - $top_chunk_size
	set $fragmentation = ((double) $free_in_arena/($alloc_reached[0] - $top_chunk_size))*100
	
	printf "Chunk count in arena: %i,\n", $count_in_arena
	printf "Biggest chunk size: %i bytes,\n", $biggest_free_size	
	printf "Heap segment size: %i bytes (%i KiB, %i MiB),\n", $alloc_reached[0], $alloc_reached[0]/1024, $alloc_reached[0]/1024/1024
	printf "Allocated memory: %i bytes (%i KiB, %i MiB),\n", $live_memory, $live_memory/1024, $live_memory/1024/1024
	printf "Freed memory: %i bytes (%i KiB, %i MiB),\n", $free_in_arena, $free_in_arena/1024, $free_in_arena/1024/1024
	printf "Top chunk size: %i bytes (%i KiB, %i MiB),\n", $top_chunk_size, $top_chunk_size/1024, $top_chunk_size/1024/1024
	printf "Fragmentation (free memory in bins)/(alocated and freed memory): %i%%\n", $fragmentation
end

# $arg0: main arena address
define analyze
	set logging on
	set $free_in_arena = 0
	set $bin_nu = 0
	set $biggest_free_size = 0
	set $count_in_arena = 0

	# go through all bins
	while ($bin_nu < 127)
		free_chunk_list $arg0 $bin_nu
		if ($biggest_free_size < $chunk_max_size)
			set $biggest_free_size = $chunk_max_size
		end
		set $bin_nu = $bin_nu + 1
		set $free_in_arena = $free_in_arena + $total_size
		set $count_in_arena = $count_in_arena + $chunk_count
	end

	print_stat $arg0
	set logging off
end
