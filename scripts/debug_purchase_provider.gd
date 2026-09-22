class_name DebugPurchaseProvider
extends RefCounted

signal purchase_completed(product_id: String)
signal purchase_failed(message: String)
signal restore_completed(product_ids: Array[String])

const PRODUCT_ID := "synapse.advanced_network_pack"

func list_products() -> Array[Dictionary]:
	return [{
		"id": PRODUCT_ID,
		"title": "Advanced Network Pack",
		"price": "$3.99 DEBUG",
		"description": "Four stronger topology cards. Also earnable for 12 Gene Shards."
	}]

func purchase(product_id: String) -> void:
	if product_id != PRODUCT_ID:
		purchase_failed.emit("Unknown debug product")
		return
	purchase_completed.emit(product_id)

func restore(owned_packs: Array) -> void:
	var restored: Array[String] = []
	if "advanced_network_pack" in owned_packs:
		restored.append(PRODUCT_ID)
	restore_completed.emit(restored)

