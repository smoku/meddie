import Sortable from "sortablejs"

const SortablePeople = {
  mounted() {
    this.sortable = new Sortable(this.el, {
      animation: 150,
      ghostClass: "opacity-30",
      onEnd: () => {
        const ids = [...this.el.querySelectorAll("[data-person-id]")]
          .map(el => el.dataset.personId)
        this.pushEvent("reorder_people", { ids })
      }
    })
  },

  destroyed() {
    if (this.sortable) this.sortable.destroy()
  }
}

export default SortablePeople
