(function(){
	jQuery(function() {
		$('form#s').submit(function(e) {
			e.preventDefault();
			var k = $(this).find("#q").val();
			if (k) {
				$.post("/translate",{term: k}, function(result) {
					$('#leftArea').attr('src', result.left);
					$('#rightArea').attr('src', result.right);
				})
			};
		});

	});
}).call(this);