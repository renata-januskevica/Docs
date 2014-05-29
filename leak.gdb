#***************************************************#
# Autore: Renata Januškeviča
# 29.05.2014
# Lai palaistu skriptu, ir nepieciešams:
# 1) ielādēt skriptu gdb atkļūdotājā ar "source <script.gdb>" komandu,
# 2) izsaukt lietotāja definēto komandu analyze ar 1 argumentu,
# $arg0: galvenās arēnas adrese, kuru iespējams iegūt ar komandas "p &main_arena" palīdzību;
# Pirms sāks skripta izpildi ir nepieciešams novietot atmiņas izmeti darbā mapē un jāpaliecinās, ka atmiņas izmetes nosaukums ir core
# Piemēram: "analyze 0x845e000"
#***************************************************#

# $arg0: galvenās arēnas adrese
# komanda apstaiga kaudzi, saskaita gabalu skaitu bez norādēm un  izdruka rezultātu
define get_alloc_chunk
	# mainīgie, kas palīdz iegūt norādi uz kaudzi
	set $top_address = (long *) ($arg0 + 48)
	set $system_mem = (long *) ($arg0 + 1096)
	set $top_size_address = (long *) ($top_address[0] + 4)
	set $top_chunk_size = $top_size_address[0] & ~7
	set $heap_pointer =  (long *) ($top_address[0] - $system_mem[0] + $top_chunk_size)
	# $malloc_pointer ir norāde, kura tiek atgriezta programmai
	set $malloc_pointer = 0
 	# $ skaitītājs atmiņas gabaliem bez norādēm
	set $unref = 0

	while ($heap_pointer != $top_address[0])
		# nākamā atmiņas gabalā atrodas kontroles zīmes, p zīme palīdz noteikt vai iepriekšējais gabals tiek iedalīts programmai
		set $next_chunk =  $heap_pointer + (($heap_pointer[1] & ~7)/4)
		# $x mainīgajā tiek saglabāta atrasta simbolu virkne, kas atrasta heksadecimalajā failā
		set $x = 0
		if (($next_chunk[1] & 1) == 1)
			set $malloc_pointer = $heap_pointer + 2

			# notiek meklēšana
			eval "shell cat gdb.core | grep %x > gdb.log", $addr
			shell echo set \$x=\"$(cat gdb.log)\" > gdb.log
			source gdb.log

			if (sizeof($x) == 1) 
				set $unref = $unref + 1
                printf "Nav atrasta norāde uz %x adresi.\n", $malloc_pointer
			end
			# komanda izdzēš .log datnes saturu
			shell > gdb.log	
		end
		# kārtējais gabals ir apstrādāts, ir nepieciešams pārvietot kaudzes norādi
		set $heap_pointer =  $heap_pointer + (($heap_pointer[1] & ~7)/4)
	end
	shell rm gdb.log
	printf "Procesa adrešu telpā nav atrastas %i norādes.", $unref	
end

# $arg0: galvenās arēnas adrese
# komanda saglabā atmiņas izmeti heksadecimālā formātā un izdzēš atstarpes, jo dati var nebūt izklidzināti
define analyze
	shell od -t x core > gdb_tmp.core
	shell cat gdb_tmp.core | tr -d ' ' > gdb.core
	shell rm gdb_tmp.core
	get_alloc_chunk $arg0
end